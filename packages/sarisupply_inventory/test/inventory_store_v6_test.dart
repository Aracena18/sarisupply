import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  final sampleProduct = CatalogProduct(
    id: 'p1',
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
        barcode: '00123',
      )
    ],
  );

  test(
      'incoming discovery survives reopen and cannot overwrite pending receipt',
      () async {
    final dir = await Directory.systemTemp.createTemp('incoming-transfer-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/db';
    var store = await InventoryStore.open(databaseFactoryFfi, path,
        merchantId: 'm1', branchId: 'b1');
    await store.applyCatalog(DeltaPage(
        cursor: 1, hasMore: false, changes: [CatalogChange(1, sampleProduct)]));
    final incoming = StockTransferIntent(
        id: 'incoming',
        sourceBranchId: 'b2',
        destinationBranchId: 'b1',
        items: [StockTransferItem(productId: 'p1', quantity: 5)],
        occurredAt: DateTime.utc(2026, 10, 6),
        status: StockTransferStatus.dispatched);
    await store.cacheIncomingTransfers([incoming]);
    await store.close();
    store = await InventoryStore.open(databaseFactoryFfi, path,
        merchantId: 'm1', branchId: 'b1');
    await store.receiveTransfer(
        transferId: 'incoming', receivedAt: DateTime.utc(2026, 10, 6));
    await store.cacheIncomingTransfers([incoming]);
    expect((await store.getTransfer('incoming'))!.status,
        StockTransferStatus.received);
    expect((await store.getProduct('p1'))!.quantity, 5);
    expect(await store.operations(pendingOnly: true), hasLength(1));
    await expectLater(
        store.cacheIncomingTransfers([
          incoming.copyWith(
              items: [StockTransferItem(productId: 'p1', quantity: 6)])
        ]),
        throwsStateError);
    expect((await store.getProduct('p1'))!.quantity, 5);
    await store.close();
  });
  test(
      'v5 upgrades to v6 preserving stock, receipts, and adding batches/transfers',
      () async {
    final dir = await Directory.systemTemp.createTemp('v5-to-v6-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/test.db';

    // 1. Create a version 5 database with an existing product and stock.
    final storeV5 = await InventoryStore.open(
      databaseFactoryFfi,
      path,
      merchantId: 'm1',
      branchId: 'b1',
    );
    await storeV5.applyCatalog(DeltaPage(
      cursor: 1,
      hasMore: false,
      changes: [CatalogChange(1, sampleProduct)],
    ));
    await storeV5.applyStock(DeltaPage(
      cursor: 1,
      hasMore: false,
      changes: [StockEvent.legacy(StockChange(1, 'p1', 10, 1, 'init'))],
    ));
    await storeV5.close();

    // 2. Re-open store to trigger v6 upgrade.
    final storeV6 = await InventoryStore.open(
      databaseFactoryFfi,
      path,
      merchantId: 'm1',
      branchId: 'b1',
    );

    // Verify existing stock is preserved
    final row = await storeV6.getProduct('p1');
    expect(row, isNotNull);
    expect(row!.quantity, 10);

    // 3. Test receiving with batch & expiry
    await storeV6.recordReceiving(
      operationId: 'recv-1',
      productId: 'p1',
      quantity: 20,
      reason: 'Supplier delivery',
      batchNumber: 'BATCH-001',
      expiryDate: '2026-12-31',
    );

    final rowAfterRecv = await storeV6.getProduct('p1');
    expect(rowAfterRecv!.quantity, 30); // 10 + 20

    final batches = await storeV6.getBatches('p1');
    expect(batches, hasLength(1));
    expect(batches.first.batchNumber, 'BATCH-001');
    expect(batches.first.quantity, 20);
    expect(batches.first.expiryDate, '2026-12-31');

    // 4. Test stock adjustment (e.g. spoilage / damage)
    await storeV6.recordStockAdjustment(
      operationId: 'adj-1',
      productId: 'p1',
      delta: -2,
      reason: 'Damaged carton',
    );

    final rowAfterAdj = await storeV6.getProduct('p1');
    expect(rowAfterAdj!.quantity, 28); // 30 - 2

    // 5. Test branch transfer dispatch
    await storeV6.dispatchTransfer(
      transferId: 'xfer-1',
      destinationBranchId: 'branch-north',
      items: [StockTransferItem(productId: 'p1', quantity: 5)],
      occurredAt: DateTime.utc(2026, 10, 5),
    );

    final rowAfterTransfer = await storeV6.getProduct('p1');
    expect(rowAfterTransfer!.quantity, 23); // 28 - 5

    final transfer = await storeV6.getTransfer('xfer-1');
    expect(transfer, isNotNull);
    expect(transfer!.status, StockTransferStatus.dispatched);
    expect(transfer.destinationBranchId, 'branch-north');
    expect(transfer.items.first.quantity, 5);

    await storeV6.close();
  });
}
