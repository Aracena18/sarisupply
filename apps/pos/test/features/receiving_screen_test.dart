import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/inventory/presentation/receiving_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/ui_fixtures.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await loadUiFonts();
  });

  late Directory dir;
  late InventoryStore store;
  final product = CatalogProduct(
    id: 'prod-milk',
    sku: 'MILK-01',
    name: 'Bear Brand Milk',
    baseUnit: 'can',
    active: true,
    revision: 1,
    units: [
      CatalogUnit(name: 'can', factor: 1, priceCentavos: 1500, barcode: '1111'),
    ],
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pos-receiving-test-');
    store = await InventoryStore.open(
      databaseFactoryFfi,
      '${dir.path}/db',
      merchantId: 'm1',
      branchId: 'b1',
    );
    await store.applyCatalog(
      DeltaPage(
          cursor: 1, hasMore: false, changes: [CatalogChange(1, product)]),
    );
  });

  tearDown(() async {
    await store.close();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'ReceivingScreen displays responsive layout at $width / $scale',
          (tester) async {
        fixtureSize(tester, width);
        await tester.pumpWidget(
          fixtureApp(ReceivingScreen(store: store, product: product),
              scale: scale),
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(AppBar, 'Receive Stock'), findsOneWidget);
        expect(find.text('Bear Brand Milk'), findsOneWidget);
        expect(find.text('Quantity (can)'), findsOneWidget);
        expect(
            find.widgetWithText(FilledButton, 'Receive Stock'), findsOneWidget);
      });
    }
  }

  testWidgets('ReceivingScreen records receiving with batch and expiry',
      (tester) async {
    fixtureSize(tester, 390.0);
    var receivedCalled = false;
    await tester.pumpWidget(
      fixtureApp(
        ReceivingScreen(
          store: store,
          product: product,
          onReceived: () => receivedCalled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity (can)'), '24');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Batch / Lot Number (optional)'),
        'LOT-9988');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Expiry Date (optional)'),
        '2027-12-31');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason / Supplier info'),
        'Delivery PO-1234');
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Receive Stock');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!receivedCalled && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    expect(receivedCalled, isTrue);

    final batches = await tester.runAsync(() => store.getBatches('prod-milk'));
    expect(batches, hasLength(1));
    expect(batches!.first.batchNumber, 'LOT-9988');
    expect(batches.first.expiryDate, '2027-12-31');
    expect(batches.first.quantity, 24);

    final row = await tester.runAsync(() => store.getProduct('prod-milk'));
    expect(row, isNotNull);
    expect(row!.quantity, 24);
  });
}
