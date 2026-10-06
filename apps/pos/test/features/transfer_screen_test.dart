import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/inventory/presentation/transfer_screen.dart';
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
    id: 'prod-noodles',
    sku: 'NOODLE-01',
    name: 'Lucky Me Pancit Canton',
    baseUnit: 'pack',
    active: true,
    revision: 1,
    units: [
      CatalogUnit(
          name: 'pack', factor: 1, priceCentavos: 1800, barcode: '3333'),
    ],
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pos-transfer-test-');
    store = await InventoryStore.open(
      databaseFactoryFfi,
      '${dir.path}/db',
      merchantId: 'm1',
      branchId: 'branch-main',
    );
    await store.applyCatalog(
      DeltaPage(
          cursor: 1, hasMore: false, changes: [CatalogChange(1, product)]),
    );
    await store.recordReceiving(
      operationId: 'init-noodles',
      productId: 'prod-noodles',
      quantity: 50,
      reason: 'Opening balance',
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
          'TransferScreen displays responsive layout at $width / $scale',
          (tester) async {
        fixtureSize(tester, width);
        await tester.pumpWidget(
          fixtureApp(
            TransferScreen(store: store, initialProduct: product),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Branch Transfers'), findsOneWidget);
        expect(find.text('Dispatch (Out)'), findsOneWidget);
        expect(find.text('Receive (In)'), findsOneWidget);
      });
    }
  }

  testWidgets('TransferScreen dispatches stock transfer', (tester) async {
    fixtureSize(tester, 390.0);
    var completedCalled = false;
    await tester.pumpWidget(
      fixtureApp(
        TransferScreen(
          store: store,
          initialProduct: product,
          onCompleted: () => completedCalled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Destination Branch ID'),
        'branch-north');
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '15');
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(FilledButton, 'Add Item');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Items to Dispatch (1)'), findsOneWidget);

    final dispatchButton =
        find.widgetWithText(FilledButton, 'Dispatch Transfer');
    await tester.ensureVisible(dispatchButton);
    await tester.tap(dispatchButton);
    await tester.pump();
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!completedCalled && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    expect(completedCalled, isTrue);

    final transfers = await tester.runAsync(() => store.listTransfers());
    expect(transfers, hasLength(1));
    expect(transfers!.first.destinationBranchId, 'branch-north');
    expect(transfers.first.items.first.productId, 'prod-noodles');
    expect(transfers.first.items.first.quantity, 15);

    // Verify stock at source branch decreased by 15 (50 - 15 = 35)
    final row = await tester.runAsync(() => store.getProduct('prod-noodles'));
    expect(row!.quantity, 35);
  });
}
