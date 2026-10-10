import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';
import 'package:sarisupply_pos/features/checkout/checkout_controller.dart';
import 'package:sarisupply_pos/features/management/presentation/management_screen.dart';
import 'package:sqflite/sqflite.dart';

// Native SQLite and real production controllers/widgets; no Firebase calls,
// real grants, merchant databases, or server mutations. Every database is in
// a fresh temporary directory, deleted after the measurement.
class _UnusedRepository extends Fake
    implements MembershipRepository, CashierRepository, DeviceRepository {}

class _InventoryApi extends Fake implements InventoryGateway {}

class _CheckoutApi extends Fake implements CheckoutGateway {}

class _Pages extends Fake implements ManagementRepository {
  int calls = 0;
  @override
  Future<ManagementPage> list(String merchantId, ManagementKind kind,
      {String? cursor}) async {
    calls++;
    // Controlled latency makes redundant reads measurable without a server.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return ManagementPage(records: [
      ManagementRecord(
          id: kind.name,
          name: 'Benchmark ${kind.name}',
          code: '',
          status: 'active',
          branchIds: const ['b'],
          allBranches: false)
    ], nextCursor: null);
  }
}

Map<String, Object?> summary(List<double> samples) {
  final sorted = [...samples]..sort();
  return {
    'samples': samples,
    'count': sorted.length,
    'medianMs': sorted[sorted.length ~/ 2],
    'p95Ms': sorted[(sorted.length * .95).ceil() - 1],
    'maxMs': sorted.last
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('20 profile samples of cached navigation and native local work',
      (tester) async {
    final dir =
        await Directory.systemTemp.createTemp('sarisupply-performance-');
    final store = await InventoryStore.open(
        databaseFactory, '${dir.path}/retail.db',
        merchantId: 'benchmark', branchId: 'b');
    final proofs = await CompanyWorkStore.open(
        databaseFactory, '${dir.path}/proof.db',
        companyId: 'benchmark', uid: 'fixture', role: 'rider');
    final results = <String, Object?>{};
    Future<void> measure(String name, Future<void> Function(int) action) async {
      final values = <double>[];
      for (var i = 0; i < 20; i++) {
        final timer = Stopwatch()..start();
        await action(i);
        timer.stop();
        values.add(timer.elapsedMicroseconds / 1000);
      }
      results[name] = summary(values);
    }

    try {
      final products = List.generate(
          1000,
          (i) => CatalogProduct(
                  id: 'p$i',
                  sku: 'SKU$i',
                  name: 'Product ${i.toString().padLeft(4, '0')}',
                  baseUnit: 'piece',
                  active: true,
                  revision: 1,
                  units: [
                    CatalogUnit(
                        name: 'piece',
                        factor: 1,
                        priceCentavos: 100,
                        barcode: 'fixture-$i')
                  ]));
      for (var start = 0; start < products.length; start += 50) {
        final end = min(start + 50, products.length);
        await store.applyCatalog(
            DeltaPage(cursor: end, hasMore: end < products.length, changes: [
          for (var i = start; i < end; i++) CatalogChange(i + 1, products[i])
        ]));
      }
      await store.search('Product 00');
      await measure('localSearch', (_) async {
        await store.search('Product 00');
      });
      await measure(
          'stockCommit',
          (i) => store.recordReceiving(
              operationId: 'fixture-stock-$i',
              productId: 'p0',
              quantity: 1,
              reason: 'Isolated performance fixture'));
      await measure(
          'proofCommit',
          (i) => proofs.queueProof('fixture-proof-$i', {
                'runId': 'fixture-run',
                'stopId': 'fixture-stop',
                'expectedRevision': i + 1
              }, {
                'id': 'fixture-run',
                'revision': i + 2
              }));

      final now = DateTime.now().toUtc();
      final scope = CheckoutScope(
          merchantId: 'benchmark',
          branchId: 'b',
          deviceId: 'fixture-device',
          cashierId: 'fixture-cashier',
          grantId: 'fixture-grant',
          credentialVersion: 1);
      await store.checkout.openShift(CheckoutIntent(
          id: 'fixture-shift',
          scope: scope,
          shiftId: 'fixture-shift',
          ordinal: 1,
          occurredAt: now,
          kind: 'openShift',
          payload: const {'floatCentavos': 0}));
      final unused = _UnusedRepository();
      final controller = CheckoutController(
          store: store,
          session: CashierSession(
              cashierId: scope.cashierId,
              deviceId: scope.deviceId,
              startedAt: now),
          authorize: () async => CheckoutAuthorization(
              scope: scope,
              occurredAt: now,
              merchantName: 'Fixture',
              branchName: 'Fixture'),
          inventoryGateway: _InventoryApi(),
          checkoutGateway: _CheckoutApi(),
          grantResolver: (_) async => null);
      await controller.load();
      await measure('cartAdd',
          (_) => controller.add(products.first, products.first.units.first));
      expect(controller.draft!.lines.single.quantity, 20);
      await measure('saleCommit', (i) async {
        final sale = CheckoutSale(
            id: 'fixture-sale-$i',
            scope: scope,
            shiftId: 'fixture-shift',
            ordinal: i + 2,
            occurredAt: now,
            merchantName: 'Fixture',
            branchName: 'Fixture',
            lines: [
              CartLine(
                  productId: 'p0',
                  sku: 'SKU0',
                  name: products.first.name,
                  unit: 'piece',
                  factor: 1,
                  priceCentavos: 100,
                  quantity: 1,
                  catalogSequence: 1,
                  catalogRevision: 1)
            ],
            tender: Tender.cash(100));
        // Include the frozen payment draft and the atomic financial commit.
        await store.checkout.saveDraft(CheckoutDraft(
            scope: scope,
            shiftId: sale.shiftId,
            lines: sale.lines,
            frozenSale: sale));
        await store.checkout.completeSale(sale);
      });

      controller.dispose();

      final pages = _Pages();
      await tester.pumpWidget(MaterialApp(
          home: ManagementScreen(
              memberships: [
            MerchantMembership(
                userId: 'fixture',
                merchantId: 'benchmark',
                role: MerchantRole.manager,
                status: MembershipStatus.active,
                allBranches: false,
                branchIds: const ['b'],
                createdAt: now,
                createdBy: 'fixture',
                updatedAt: now)
          ],
              management: pages,
              membershipRepository: unused,
              cashiers: unused,
              devices: unused)));
      await tester.pumpAndSettle();
      Future<void> select(String label, String record) async {
        await tester.tap(find.text(label).last);
        await tester.pump();
        final limit = Stopwatch()..start();
        while (find.text('Benchmark $record').evaluate().isEmpty) {
          if (limit.elapsed > const Duration(seconds: 3)) {
            throw StateError('Navigation did not display $record');
          }
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      await select('Branches', 'branches');
      await select('Devices', 'devices');
      await select('Team', 'cashiers');
      final initialCalls = pages.calls;
      await measure(
          'warmNavigation',
          (i) => i.isEven
              ? select('Branches', 'branches')
              : select('Team', 'cashiers'));
      results['warmNavigationReads'] = pages.calls - initialCalls;
      final report = {
        'phase': const String.fromEnvironment('SARISUPPLY_PERF_PHASE',
            defaultValue: 'after'),
        'mode': 'profile',
        'products': products.length,
        'navigationServerDelayMs': 200,
        'results': results
      };
      binding.reportData = report;
      // No business IDs, credentials, customer records or payloads are logged.
      debugPrint('SARISUPPLY_PERF_RESULT ${jsonEncode(report)}',
          wrapWidth: 20000);
      await File(
              '${Directory.systemTemp.path}/sarisupply-performance-result.json')
          .writeAsString(jsonEncode(report));
      await tester.pumpWidget(const SizedBox());
    } finally {
      await store.close();
      await proofs.close();
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
