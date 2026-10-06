import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sarisupply_pos/features/catalog/catalog_screen.dart';

class OfflineGateway implements InventoryGateway {
  @override
  Future<DeltaPage<CatalogChange>> pullCatalog(
          String m, String b, int cursor) async =>
      throw StateError('secret server failure');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DeniedGateway extends OfflineGateway {
  @override
  Future<DeltaPage<CatalogChange>> pullCatalog(
          String m, String b, int cursor) async =>
      throw FirebaseException(plugin: 'test', code: 'permission-denied');
}

// Allow real SQLite work to finish before settling simulated frame time.
Future<void> pumpCatalogUntil(
    WidgetTester tester, bool Function() ready) async {
  await tester.pump();
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
  }
  expect(ready(), isTrue,
      reason: 'Catalog did not reach the expected visible state');
  await tester.pumpAndSettle();
}

void main() {
  sqfliteFfiInit();
  testWidgets(
      'device authorization denial requests gate recovery and retains business file',
      (tester) async {
    late Directory dir;
    late InventoryStore store;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('denied-stock-');
      store = await InventoryStore.open(
          databaseFactoryFfi, '${dir.path}/stock.db',
          merchantId: 'm', branchId: 'b');
    });
    var denied = 0;
    await tester.pumpWidget(MaterialApp(
        home: CatalogScreen(
            branchName: 'Main',
            openStore: () async => store,
            gateway: DeniedGateway(),
            canUpload: false,
            canEdit: false,
            onAccessDenied: () async {
              denied++;
            })));
    await pumpCatalogUntil(
        tester, () => find.byType(LinearProgressIndicator).evaluate().isEmpty);
    await tester.tap(find.text('Sync'));
    await pumpCatalogUntil(
        tester,
        () =>
            denied == 1 &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty);
    expect(denied, 1);
    await tester.runAsync(() async {
      expect(await File('${dir.path}/stock.db').exists(), isTrue);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
  });

  testWidgets(
      'cashier sees local prices and shortage with safe retry feedback; no edit controls',
      (tester) async {
    late Directory dir;
    late InventoryStore store;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('catalog-ui-');
      store = await InventoryStore.open(
          databaseFactoryFfi, '${dir.path}/stock.db',
          merchantId: 'm', branchId: 'b');
      final p = CatalogProduct(
          id: 'p',
          sku: 'MILK',
          name: 'Milk',
          baseUnit: 'piece',
          revision: 1,
          active: true,
          units: [
            CatalogUnit(
                name: 'piece',
                factor: 1,
                priceCentavos: 1250,
                barcode: '00123'),
            CatalogUnit(
                name: 'pack', factor: 6, priceCentavos: 7000, barcode: '00999')
          ]);
      await store.applyCatalog(
          DeltaPage(cursor: 1, hasMore: false, changes: [CatalogChange(1, p)]));
      await store.applyStock(DeltaPage(
          cursor: 1,
          hasMore: false,
          changes: [StockEvent.legacy(StockChange(1, 'p', -3, 1, 'op'))]));
    });
    await tester.pumpWidget(MaterialApp(
        home: CatalogScreen(
            branchName: 'Main store',
            openStore: () async => store,
            gateway: OfflineGateway(),
            canUpload: false,
            canEdit: false)));
    await pumpCatalogUntil(
        tester,
        () =>
            find.text('Milk').evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.textContaining('12.50'), findsOneWidget);
    expect(find.textContaining('Short 3'), findsOneWidget);
    expect(find.text('Add product'), findsNothing);
    expect(find.textContaining('70.00'), findsNothing);
    await tester.enterText(find.byType(TextField), '00999');
    await tester.pump(const Duration(milliseconds: 160));
    await pumpCatalogUntil(tester,
        () => find.text('Barcode match: pack · ₱70.00').evaluate().isNotEmpty);
    expect(find.text('Barcode match: pack · ₱70.00'), findsOneWidget);
    await tester.tap(find.text('Sync'));
    await pumpCatalogUntil(
        tester, () => find.byType(LinearProgressIndicator).evaluate().isEmpty);
    expect(find.textContaining('secret server failure'), findsNothing);
    expect(find.text('Milk'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
  });
}
