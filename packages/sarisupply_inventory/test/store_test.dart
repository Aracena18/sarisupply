import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final product = CatalogProduct(
    id: 'p',
    sku: 'MILK',
    name: 'Milk',
    baseUnit: 'piece',
    revision: 1,
    active: true,
    units: [
      CatalogUnit(
          name: 'piece', factor: 1, priceCentavos: 1250, barcode: '00123'),
      CatalogUnit(
          name: 'pack', factor: 6, priceCentavos: 7000, barcode: '00124')
    ]);
void main() {
  sqfliteFfiInit();
  late Directory dir;
  late InventoryStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sarisupply-stock-');
    store = await InventoryStore.open(
        databaseFactoryFfi, '${dir.path}/stock.db',
        merchantId: 'm', branchId: 'b');
    await store.applyCatalog(DeltaPage(
        cursor: 1, hasMore: false, changes: [CatalogChange(1, product)]));
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  test('pending receiving follows remote changes and settles without doubling',
      () async {
    await store.applyStock(DeltaPage(
        cursor: 1,
        hasMore: false,
        changes: [StockEvent.legacy(StockChange(1, 'p', 10, 1, 'initial'))]));
    await store.recordReceiving(
        operationId: 'receive',
        productId: 'p',
        quantity: 5,
        reason: 'Delivery');
    expect((await store.getProduct('p'))!.quantity, 15);
    expect((await store.db.query('stock')).single['quantity'], 10);
    await store.applyStock(DeltaPage(cursor: 2, hasMore: false, changes: [
      StockEvent(
          sequence: 2,
          operationId: 'other-device',
          kind: 'sale',
          positions: [StockPosition('p', 8, 2, delta: -2)])
    ]));
    expect((await store.getProduct('p'))!.quantity, 13);
    await store.applyStock(DeltaPage(cursor: 3, hasMore: false, changes: [
      StockEvent(
          sequence: 3,
          operationId: 'receive',
          kind: 'receiving',
          positions: [StockPosition('p', 13, 3, delta: 5)])
    ]));
    expect((await store.getProduct('p'))!.quantity, 13);
    expect(await store.pending(), isEmpty);
  });

  test('file reopen preserves catalog, barcode unit, stock and pending UUID',
      () async {
    await store.recordCount(
        id: 'op',
        productId: 'p',
        quantity: 12,
        kind: 'opening',
        reason: 'Initial stock');
    await store.close();
    store = await InventoryStore.open(
        databaseFactoryFfi, '${dir.path}/stock.db',
        merchantId: 'm', branchId: 'b');
    expect((await store.search('milk')).single.product.sku, 'MILK');
    expect((await store.lookupBarcode('00124'))!.unit.factor, 6);
    expect((await store.search('')).single.quantity, 12);
    expect((await store.pending()).single.id, 'op');
    expect((await store.operations(unsettledOnly: true)).single.productName,
        'Milk');
  });
  test('duplicate operation is rejected atomically, projection unchanged',
      () async {
    await store.recordCount(
        id: 'op',
        productId: 'p',
        quantity: 12,
        kind: 'opening',
        reason: 'Initial stock');
    await expectLater(
        store.recordCount(
            id: 'op',
            productId: 'p',
            quantity: 30,
            kind: 'count',
            reason: 'Count'),
        throwsA(anything));
    expect((await store.search('')).single.quantity, 12);
    expect(await store.ledgerCount(), 1);
  });
  test('lost ACK then stock delta settles local operation without double count',
      () async {
    await store.recordCount(
        id: 'op',
        productId: 'p',
        quantity: 12,
        kind: 'opening',
        reason: 'Initial stock');
    await store.applyStock(DeltaPage(
        cursor: 1,
        hasMore: false,
        changes: [StockEvent.legacy(StockChange(1, 'p', 12, 1, 'op'))]));
    expect((await store.search('')).single.quantity, 12);
    expect(await store.pending(), isEmpty);
  });
  test('ACK before delta and negative stock replay never duplicate quantity',
      () async {
    await store.recordCount(
        id: 'op',
        productId: 'p',
        quantity: 12,
        kind: 'opening',
        reason: 'Initial stock');
    await store.acknowledge('op', StockAck('op', 'accepted', sequence: 1));
    expect((await store.search('')).single.quantity, 12);
    await store.applyStock(DeltaPage(cursor: 2, hasMore: false, changes: [
      StockEvent.legacy(StockChange(1, 'p', 12, 1, 'op')),
      StockEvent.legacy(StockChange(2, 'p', -3, 2, 'other'))
    ]));
    expect((await store.search('')).single.quantity, -3);
  });
  test('gapped page rolls back all changes and cursor', () async {
    await expectLater(
        store.applyStock(DeltaPage(cursor: 3, hasMore: false, changes: [
          StockEvent.legacy(StockChange(1, 'p', 9, 1, 'a')),
          StockEvent.legacy(StockChange(3, 'p', 0, 2, 'b'))
        ])),
        throwsFormatException);
    expect(await store.stockCursor(), 0);
    expect((await store.search('')).single.quantity, 0);
  });
  test('conflict remains visible until explicit local compensation', () async {
    await store.recordCount(
        id: 'op',
        productId: 'p',
        quantity: 12,
        kind: 'opening',
        reason: 'Initial stock');
    await store.acknowledge(
        'op', StockAck('op', 'conflict', message: 'Opening already recorded'));
    expect((await store.search('')).single.quantity, 12);
    await store.withdraw('op', 'comp');
    expect((await store.search('')).single.quantity, 0);
    expect(await store.ledgerCount(), 2);
    expect((await store.operations()).single.status, 'withdrawn');
  });
  test('catalog edit preserves referenced ledger and updated barcode',
      () async {
    await store.recordCount(
        id: 'op',
        productId: 'p',
        quantity: 12,
        kind: 'opening',
        reason: 'Initial stock');
    final updated = CatalogProduct(
        id: 'p',
        sku: 'MILK',
        name: 'Fresh milk',
        baseUnit: 'piece',
        revision: 2,
        active: true,
        units: [
          CatalogUnit(
              name: 'piece', factor: 1, priceCentavos: 1300, barcode: '00999')
        ]);
    await store.applyCatalog(DeltaPage(
        cursor: 2, hasMore: false, changes: [CatalogChange(2, updated)]));
    expect((await store.search('fresh')).single.quantity, 12);
    expect(await store.lookupBarcode('00123'), isNull);
    expect((await store.lookupBarcode('00999'))!.unit.priceCentavos, 1300);
    expect(await store.ledgerCount(), 1);
  });
  test(
      'new cloud count retains pending physical count until conflict is resolved',
      () async {
    await store.applyStock(DeltaPage(
        cursor: 1,
        hasMore: false,
        changes: [StockEvent.legacy(StockChange(1, 'p', 12, 1, 'initial'))]));
    await store.recordCount(
        id: 'mine',
        productId: 'p',
        quantity: 10,
        kind: 'count',
        reason: 'Count');
    await store.applyStock(DeltaPage(
        cursor: 2,
        hasMore: false,
        changes: [StockEvent.legacy(StockChange(2, 'p', 5, 2, 'other'))]));
    expect((await store.search('')).single.quantity, 10);
    await store.acknowledge('mine', StockAck('mine', 'conflict'));
    await store.withdraw('mine', 'reversal');
    expect((await store.search('')).single.quantity, 5);
  });
  test('outbox insert failure rolls back the entire local movement', () async {
    final connection = await databaseFactoryFfi.openDatabase(
        '${dir.path}/stock.db',
        options: OpenDatabaseOptions(singleInstance: false));
    await connection.execute(
        "CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT, 'disk fault'); END");
    await expectLater(
        store.recordCount(
            id: 'op',
            productId: 'p',
            quantity: 12,
            kind: 'opening',
            reason: 'Initial stock'),
        throwsA(anything));
    expect(await store.ledgerCount(), 0);
    expect(await store.pending(), isEmpty);
    await connection.close();
  });
  test(
      'shortage filter uses pending physical balance rather than stale cloud stock',
      () async {
    await store.applyStock(DeltaPage(
        cursor: 1,
        hasMore: false,
        changes: [StockEvent.legacy(StockChange(1, 'p', -3, 1, 'initial'))]));
    expect(await store.search('', shortagesOnly: true), hasLength(1));
    await store.recordCount(
        id: 'count',
        productId: 'p',
        quantity: 2,
        kind: 'count',
        reason: 'Physical count');
    expect(await store.search('', shortagesOnly: true), isEmpty);
  });
  test('malformed delta cannot settle a different product or quantity',
      () async {
    await store.recordCount(
        id: 'mine',
        productId: 'p',
        quantity: 12,
        kind: 'opening',
        reason: 'Opening');
    await expectLater(
        store.applyStock(DeltaPage(cursor: 1, hasMore: false, changes: [
          StockEvent.legacy(StockChange(1, 'foreign', 20, 1, 'mine'))
        ])),
        throwsFormatException);
    expect(await store.stockCursor(), 0);
    expect(await store.pending(), hasLength(1));
  });
  test('ACK awaiting delta blocks a new physical count from stale base',
      () async {
    await store.recordCount(
        id: 'mine',
        productId: 'p',
        quantity: 12,
        kind: 'opening',
        reason: 'Opening');
    await store.acknowledge('mine', StockAck('mine', 'accepted', sequence: 1));
    expect((await store.search('')).single.unsettled, 1);
    await expectLater(
        store.recordCount(
            id: 'new',
            productId: 'p',
            quantity: 15,
            kind: 'count',
            reason: 'Count'),
        throwsStateError);
  });
  test('ACK behind an already consumed feed remains pending', () async {
    await store.recordCount(
        id: 'mine',
        productId: 'p',
        quantity: 12,
        kind: 'opening',
        reason: 'Opening');
    await store.applyStock(DeltaPage(cursor: 1, hasMore: false, changes: [
      StockEvent.legacy(const StockChange(1, 'p', 10, 1, 'other'))
    ]));
    await expectLater(
        store.acknowledge(
            'mine', const StockAck('mine', 'accepted', sequence: 1)),
        throwsFormatException);
    expect((await store.pending()).single.id, 'mine');
  });
  test('database cannot be opened under a different branch', () async {
    await expectLater(
        InventoryStore.open(databaseFactoryFfi, '${dir.path}/stock.db',
            merchantId: 'm', branchId: 'foreign'),
        throwsStateError);
  });
}
