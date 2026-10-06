import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/inventory/presentation/adjustment_screen.dart';
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
    id: 'prod-corned-beef',
    sku: 'CB-01',
    name: 'Purefoods Corned Beef',
    baseUnit: 'can',
    active: true,
    revision: 1,
    units: [
      CatalogUnit(name: 'can', factor: 1, priceCentavos: 4500, barcode: '2222'),
    ],
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pos-adjustment-test-');
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
    // Initialize initial stock of 20
    await store.recordReceiving(
      operationId: 'init-receiving',
      productId: 'prod-corned-beef',
      quantity: 20,
      reason: 'Opening stock',
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
          'AdjustmentScreen displays responsive layout at $width / $scale',
          (tester) async {
        fixtureSize(tester, width);
        final row =
            await tester.runAsync(() => store.getProduct('prod-corned-beef'));
        await tester.pumpWidget(
          fixtureApp(AdjustmentScreen(store: store, row: row), scale: scale),
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(AppBar, 'Stock Adjustment'), findsOneWidget);
        expect(find.text('Purefoods Corned Beef'), findsOneWidget);
        expect(find.text('Reduce stock (-)'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Save Adjustment'),
            findsOneWidget);
      });
    }
  }

  testWidgets('AdjustmentScreen reduces stock on reduction adjustment',
      (tester) async {
    fixtureSize(tester, 390.0);
    var adjustedCalled = false;
    final row =
        await tester.runAsync(() => store.getProduct('prod-corned-beef'));
    await tester.pumpWidget(
      fixtureApp(
        AdjustmentScreen(
          store: store,
          row: row,
          onAdjusted: () => adjustedCalled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity to reduce (can)'), '4');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'),
        'Dented can leak');
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Save Adjustment');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!adjustedCalled && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    expect(adjustedCalled, isTrue);

    final updated =
        await tester.runAsync(() => store.getProduct('prod-corned-beef'));
    expect(updated, isNotNull);
    expect(updated!.quantity, 16);
  });
}
