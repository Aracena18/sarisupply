import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sarisupply_company/src/order_shop_controller.dart';
import 'package:sarisupply_company/src/order_shop_screen.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite/sqflite.dart';

// Isolated native drafts and real ordering widgets; no identities or business writes.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('warm reorder cart edits retain catalog with zero network reads',
      (tester) async {
    final dir = await Directory.systemTemp.createTemp('reorder-benchmark-');
    final storage = await CompanyWorkStore.open(
        databaseFactory, '${dir.path}/work.db',
        companyId: 'benchmark', uid: 'fixture', role: 'store');
    var reads = 0;
    final products = List.generate(
        25,
        (i) => CompanyRecord({
              'id': 'p$i',
              'name': 'Product $i',
              'unit': 'piece',
              'priceCentavos': 100,
              'revision': 1,
              'active': true,
              'availability': 'inStock'
            }));
    final catalog = OrderCatalogController(
        storage: storage,
        read: (w, q, cursor) async {
          reads++;
          return CompanyPage(
              records: products, nextCursor: null, hasMore: false);
        });
    try {
      await tester.pumpWidget(MaterialApp(
          theme: SariSupplyTheme.light,
          home: OrderShopScreen(
              title: 'Benchmark',
              warehouses: [
                CompanyRecord({'id': 'w', 'name': 'Warehouse'})
              ],
              catalog: catalog,
              initial: {
                'warehouseId': 'w',
                'address': 'Branch',
                'contact': 'Owner',
                'phone': '123'
              },
              saveDraft: (v) => storage.saveDraft('order', v),
              clearDraft: () => storage.clearDraft('order'),
              loadPreferences: () async => {},
              loadMappings: () async => [],
              validateProducts: (w, ids) async =>
                  products.where((p) => ids.contains(p.id)).toList(),
              submit: (v) async {},
              matchProduct: (r) async => null)));
      await tester.pumpAndSettle();
      final before = reads;
      final samples = <double>[];
      for (var i = 0; i < 20; i++) {
        final timer = Stopwatch()..start();
        await tester.tap(find.byTooltip('Add product').first);
        await tester.pump();
        timer.stop();
        samples.add(timer.elapsedMicroseconds / 1000);
        await tester.tap(find.byTooltip('Remove one').first);
        await tester.pump();
      }
      expect(reads, before);
      final sorted = [...samples]..sort();
      final report = {
        'devicePlatform': Platform.operatingSystem,
        'samplesMs': samples,
        'p95Ms': sorted[(sorted.length * .95).ceil() - 1],
        'catalogReadsDuringEdits': reads - before,
        'sampleCount': samples.length,
        'targetMs': 100
      };
      binding.reportData = report;
      // ignore: avoid_print
      print('REORDER_BENCHMARK ${jsonEncode(report)}');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } finally {
      catalog.dispose();
      await storage.close();
      await dir.delete(recursive: true);
    }
  });
}
