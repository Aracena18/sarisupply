import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';
import 'package:sarisupply_pos/features/cashier_auth/presentation/cashier_login_screen.dart';
import 'package:sarisupply_pos/features/cashier_auth/presentation/change_temporary_pin_screen.dart';
import 'package:sarisupply_pos/features/cashier_auth/presentation/offline_auth_blocked_screen.dart';
import 'package:sarisupply_pos/features/device_setup/presentation/device_setup_screen.dart';
import 'package:sarisupply_pos/features/owner_onboarding/presentation/owner_onboarding_gate.dart';
import 'package:sarisupply_pos/features/management/presentation/management_screen.dart';
import 'package:sarisupply_pos/features/management/presentation/management_form_dialog.dart';
import 'package:sarisupply_pos/features/catalog/product_dialog.dart';
import 'package:sarisupply_pos/features/catalog/catalog_screen.dart';
import 'package:sarisupply_pos/features/catalog/catalog_branch_screen.dart';
import '../support/ui_fixtures.dart';

CashierLoginScreen cashier() => CashierLoginScreen(
    loadCashiers: () async => [
          CashierCredentialProjection(
              cashierId: 'ana',
              displayName: 'Ana Santos',
              employeeCode: 'EMP01',
              status: 'active',
              assignedBranchIds: ['main'],
              mustChangePin: false,
              credentialVersion: 1)
        ],
    onLogin: (_, __) async =>
        const CashierLoginResult(CashierLoginStatus.invalidPin),
    onResult: (_, __) {},
    onManage: () {});
ManagementScreen management(FixtureManagement repo) => ManagementScreen(
    memberships: [fixtureMember()],
    management: repo,
    membershipRepository: FixtureMemberships(),
    cashiers: FixtureCashiers(),
    devices: FixtureDevices());
Future<void> flushStore(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await loadUiFonts();
  });
  for (final width in [320.0, 390.0, 600.0, 1024.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('access and management surfaces at $width / $scale',
          (tester) async {
        fixtureSize(tester, width);
        final memberships = FixtureMemberships();
        for (final screen in <Widget>[
          cashier(),
          ChangeTemporaryPinScreen(
              cashierId: 'ana',
              onChange: (_, __, ___) async =>
                  const CashierLoginResult(CashierLoginStatus.invalidPin),
              onResult: (_) {}),
          for (final revoked in [true, false])
            OfflineAuthBlockedScreen(revoked: revoked, onRetry: () {}),
          DeviceSetupScreen(
              memberships: [fixtureMember()],
              membershipRepository: memberships,
              devices: FixtureDevices(),
              onActivated: () {},
              onSignOut: () {}),
          for (final status in [
            MerchantApplicationStatus.draft,
            MerchantApplicationStatus.rejected
          ])
            OwnerOnboardingGate(
                applications: FixtureApplications(),
                memberships: memberships,
                existing: fixtureApplication(status),
                onChanged: () {},
                onSignOut: () {}),
          management(FixtureManagement()),
          for (final action in ManagementAction.values)
            ManagementFormDialog(
                action: action,
                branches: [fixtureBranch('main')],
                onSubmit: (_, __, ___, ____) async => null),
        ]) {
          await tester.pumpWidget(fixtureApp(screen, scale: scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '${screen.runtimeType}');
        }
      });
      testWidgets(
          '12-unit product stays editable with keyboard at $width / $scale',
          (tester) async {
        fixtureSize(tester, width);
        CatalogProduct? saved;
        final product = fixtureProduct(units: 12);
        await tester.pumpWidget(fixtureApp(
            ProductDialog(
                product: product,
                onSave: (p, id) async {
                  saved = p;
                  return p;
                }),
            scale: scale,
            keyboard: 280));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.widgetWithText(TextFormField, 'Product name'),
            'A long product name from a local supplier');
        await tester.tap(find.text('Save product'));
        await tester.pumpAndSettle();
        expect(saved?.units.length, 12);
        expect(saved?.units.first.barcode, '000123');
        expect(saved?.units.first.priceCentavos, 5500);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
      'phone to dialog resize keeps product input and uncertain retry ID',
      (tester) async {
    fixtureSize(tester, 390);
    final ids = <String>[];
    final products = <CatalogProduct>[];
    await tester.pumpWidget(fixtureApp(ProductDialog(
        product: fixtureProduct(),
        onSave: (p, id) async {
          ids.add(id);
          products.add(p);
          throw StateError('uncertain response');
        })));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Product name'), 'Edited rice');
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1024, 844);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(ids, hasLength(2));
    expect(ids.first, ids.last);
    expect(products.last.name, 'Edited rice');
  });
  testWidgets('invitations precede registration and recover from load error',
      (tester) async {
    final memberships = FixtureMemberships()..failInvitations = true;
    await tester.pumpWidget(fixtureApp(OwnerOnboardingGate(
        applications: FixtureApplications(),
        memberships: memberships,
        onChanged: () {},
        onSignOut: () {})));
    await tester.pumpAndSettle();
    memberships.failInvitations = false;
    memberships.invitations = [
      ManagerInvitation(
          inviteId: 'inv',
          merchantId: 'store-reference',
          email: 'ana@example.com',
          allBranches: true,
          branchIds: [],
          expiresAt: DateTime.utc(2026, 10, 12))
    ];
    await tester.tap(find.text('Retry invitations'));
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.text('Manager invitations')).dy,
        lessThan(tester
            .getTopLeft(find.widgetWithText(TextFormField, 'Business name'))
            .dy));
    memberships.acceptGate = Completer<void>();
    await tester.tap(find.text('Accept invitation'));
    await tester.pump();
    await tester.tap(find.text('Accepting…'));
    await tester.pump();
    expect(memberships.accepted, 1);
    memberships.acceptGate!.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('branch errors and empty locations offer safe recovery',
      (tester) async {
    final repo = FixtureMemberships()..failBranches = true;
    await tester.pumpWidget(fixtureApp(CatalogBranchScreen(
        memberships: [fixtureMember()],
        repository: repo,
        gateway: FixtureGateway())));
    await tester.pumpAndSettle();
    expect(find.textContaining('private detail'), findsNothing);
    repo.failBranches = false;
    repo.branches.clear();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
        find.text('Create an active branch to manage stock.'), findsOneWidget);
  });
  testWidgets('sole branch opens inventory; multiple branches require choice',
      (tester) async {
    final repo = FixtureMemberships();
    await tester.pumpWidget(fixtureApp(CatalogBranchScreen(
        memberships: [fixtureMember()],
        repository: repo,
        gateway: FixtureGateway())));
    await tester.pumpAndSettle();
    expect(find.text('Inventory'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.branches.add(fixtureBranch('north'));
    await tester.pumpWidget(fixtureApp(CatalogBranchScreen(
        memberships: [fixtureMember()],
        repository: repo,
        gateway: FixtureGateway())));
    await tester.pumpAndSettle();
    expect(find.text('Select stock location'), findsOneWidget);
    expect(find.text('Inventory'), findsNothing);
  });
  for (final surface in ['cashier', 'product', 'management']) {
    testWidgets('$surface representative golden', (tester) async {
      fixtureSize(tester, 390);
      final screen = switch (surface) {
        'cashier' => cashier(),
        'product' =>
          ProductDialog(product: fixtureProduct(), onSave: (p, _) async => p),
        _ => management(FixtureManagement()),
      };
      await tester.pumpWidget(fixtureApp(screen));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../goldens/$surface.png'));
    });
  }
  testWidgets(
      'inventory count recovery is reachable above products; count context and golden',
      (tester) async {
    fixtureSize(tester, 390);
    late Directory dir;
    late InventoryStore store;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('ui-redesign-');
      store = await InventoryStore.open(
          databaseFactoryFfi, '${dir.path}/stock.db',
          merchantId: 'store', branchId: 'main');
      await store.applyCatalog(DeltaPage(cursor: 2, hasMore: false, changes: [
        CatalogChange(1, fixtureProduct()),
        CatalogChange(2, fixtureProduct(id: 'coffee'))
      ]));
      await store.applyStock(DeltaPage(cursor: 1, hasMore: false, changes: [
        StockEvent.legacy(const StockChange(1, 'rice', 24, 1, 'cloud'))
      ]));
      await store.recordCount(
          id: 'pending',
          productId: 'coffee',
          quantity: 8,
          kind: 'opening',
          reason: 'Opening delivery');
      await store.acknowledge(
          'pending',
          const StockAck('pending', 'conflict',
              message: 'Stock changed. Sync and count again.'));
    });
    await tester.pumpWidget(fixtureApp(CatalogScreen(
        branchName: 'Main branch',
        openStore: () async => store,
        gateway: FixtureGateway(),
        canUpload: true,
        canEdit: true,
        onLock: () {})));
    await flushStore(tester);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('../goldens/inventory.png'));
    // Retain this real SQLite view while resizing; check its controls and recovery summary.
    for (final width in [320.0, 390.0, 600.0, 1024.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpWidget(fixtureApp(
            CatalogScreen(
                branchName: 'Main branch',
                openStore: () async => store,
                gateway: FixtureGateway(),
                canUpload: true,
                canEdit: true,
                onLock: () {}),
            scale: scale));
        await tester.pumpAndSettle();
        expect(find.text('1 stock count · Needs review'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Inventory $width / $scale');
      }
    }
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(fixtureApp(CatalogScreen(
        branchName: 'Main branch',
        openStore: () async => store,
        gateway: FixtureGateway(),
        canUpload: true,
        canEdit: true,
        onLock: () {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 stock count · Needs review'));
    await tester.pumpAndSettle();
    expect(find.text('Withdraw'), findsOneWidget);
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(find.textContaining('retains its history'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('rice')));
    await tester.tap(find.byKey(const ValueKey('rice')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record count'));
    await tester.tap(find.text('Record count'));
    await tester.pumpAndSettle();
    expect(find.text('Current stock: 24 bag'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity (bag)'), '23');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason'), 'Physical shelf count');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save count'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(find.text('Saved locally · Sync pending'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await dir.delete(recursive: true);
    });
  });
}
