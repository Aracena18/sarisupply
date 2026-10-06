import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Gateway implements InventoryGateway {
  final pushed = <String>[];
  int catalogCalls = 0, stockCalls = 0;
  bool paged = false;
  final product = CatalogProduct(
      id: 'p',
      sku: 'P',
      name: 'Product',
      baseUnit: 'piece',
      revision: 1,
      active: true,
      units: [CatalogUnit(name: 'piece', factor: 1, priceCentavos: 100)]);
  @override
  Future<DeltaPage<CatalogChange>> pullCatalog(
      String m, String b, int cursor) async {
    catalogCalls++;
    if (paged) {
      final changes = List.generate(
          50,
          (i) => CatalogChange(
              cursor + i + 1,
              CatalogProduct(
                  id: 'p${cursor + i}',
                  sku: 'P${cursor + i}',
                  name: 'Item ${cursor + i}',
                  baseUnit: 'piece',
                  revision: 1,
                  active: true,
                  units: [
                    CatalogUnit(name: 'piece', factor: 1, priceCentavos: 100)
                  ])));
      return DeltaPage(cursor: cursor + 50, hasMore: true, changes: changes);
    }
    return DeltaPage(
        cursor: cursor == 0 ? 1 : cursor,
        hasMore: false,
        changes: cursor == 0 ? [CatalogChange(1, product)] : []);
  }

  @override
  Future<DeltaPage<StockEvent>> pullStock(
      String m, String b, int cursor) async {
    stockCalls++;
    return DeltaPage(cursor: cursor, hasMore: false, changes: []);
  }

  @override
  Future<StockAck> push(String m, String b, StockOperation op) async {
    pushed.add(op.id);
    if (op.id == 'second') throw StateError('Lost response');
    return StockAck(op.id, 'accepted', sequence: 1);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late InventoryStore store;
  late Gateway gateway;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('inventory-sync-');
    store = await InventoryStore.open(
        databaseFactoryFfi, '${dir.path}/stock.db',
        merchantId: 'm', branchId: 'b');
    gateway = Gateway();
    await store.applyCatalog(await gateway.pullCatalog('m', 'b', 0));
    gateway.catalogCalls = 0;
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  test('partial ACK is durable and retry sends only unacknowledged operation',
      () async {
    await store.recordCount(
        id: 'first',
        productId: 'p',
        quantity: 5,
        kind: 'opening',
        reason: 'Opening');
    final p = CatalogProduct(
        id: 'p2',
        sku: 'P2',
        name: 'Other',
        baseUnit: 'piece',
        revision: 1,
        active: true,
        units: [CatalogUnit(name: 'piece', factor: 1, priceCentavos: 100)]);
    await store.applyCatalog(
        DeltaPage(cursor: 2, hasMore: false, changes: [CatalogChange(2, p)]));
    await store.recordCount(
        id: 'second',
        productId: 'p2',
        quantity: 6,
        kind: 'opening',
        reason: 'Opening');
    final sync = InventorySync(store, gateway, canUpload: true);
    await expectLater(sync.run(), throwsStateError);
    expect((await store.pending()).map((o) => o.id), ['second']);
    await expectLater(sync.run(), throwsStateError);
    expect(gateway.pushed, ['first', 'second', 'second']);
  });
  test('cashier pull cannot upload human stock drafts', () async {
    await store.recordCount(
        id: 'first',
        productId: 'p',
        quantity: 5,
        kind: 'opening',
        reason: 'Opening');
    expect(await InventorySync(store, gateway, canUpload: false).run(), isTrue);
    expect(gateway.pushed, isEmpty);
    expect(await store.pending(), hasLength(1));
  });
  test('sync budget stops at five pages and retains next cursor', () async {
    gateway.paged = true;
    expect(await InventorySync(store, gateway, canUpload: false).run(), isTrue);
    expect(gateway.catalogCalls, 5);
    expect(await store.catalogCursor(), 251);
    expect(gateway.stockCalls, 1);
    expect(await store.hasPendingFeed('catalog'), isTrue);
    await store.close();
    store = await InventoryStore.open(
        databaseFactoryFfi, '${dir.path}/stock.db',
        merchantId: 'm', branchId: 'b');
    expect(await store.hasPendingSync(), isTrue);
  });
  test('malformed ACK keeps durable pending work', () async {
    await store.recordCount(
        id: 'first',
        productId: 'p',
        quantity: 5,
        kind: 'opening',
        reason: 'Opening');
    await expectLater(
        store.acknowledge(
            'first', StockAck('foreign', 'accepted', sequence: 1)),
        throwsFormatException);
    expect(await store.pending(), hasLength(1));
  });
}
