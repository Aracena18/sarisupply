import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'checkout_store_test.dart' as f;

void main() {
  sqfliteFfiInit();
  test('v3 upgrades to checkout without losing old count, cursors or backlog',
      () async {
    final dir = await Directory.systemTemp.createTemp('checkout-v3-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v3';
    final p = CatalogProduct(
        id: 'p',
        sku: 'MILK',
        name: 'Milk',
        baseUnit: 'piece',
        revision: 1,
        active: true,
        units: [
          CatalogUnit(
              name: 'piece', factor: 1, priceCentavos: 1250, barcode: '00123')
        ]);
    final db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, _) async {
              for (final sql in [
                'CREATE TABLE context(id INTEGER PRIMARY KEY,merchant TEXT,branch TEXT)',
                'CREATE TABLE products(id TEXT PRIMARY KEY,sku TEXT UNIQUE,name TEXT,active INTEGER,body TEXT)',
                'CREATE TABLE barcodes(barcode TEXT PRIMARY KEY,product TEXT,unit INTEGER)',
                'CREATE TABLE stock(product TEXT PRIMARY KEY,quantity INTEGER,revision INTEGER)',
                'CREATE TABLE ledger(id TEXT PRIMARY KEY,product TEXT,delta INTEGER,body TEXT,reverses TEXT,quantity INTEGER)',
                'CREATE TABLE outbox(id TEXT PRIMARY KEY,status TEXT,sequence INTEGER,message TEXT)',
                'CREATE TABLE cursors(feed TEXT PRIMARY KEY,value INTEGER)',
                'CREATE TABLE sync_state(feed TEXT PRIMARY KEY,has_more INTEGER NOT NULL)',
                "CREATE TRIGGER ledger_no_update BEFORE UPDATE ON ledger BEGIN SELECT RAISE(ABORT,'Immutable ledger'); END",
                "CREATE TRIGGER ledger_no_delete BEFORE DELETE ON ledger BEGIN SELECT RAISE(ABORT,'Immutable ledger'); END",
              ]) {
                await db.execute(sql);
              }
              await db
                  .insert('context', {'id': 1, 'merchant': 'm', 'branch': 'b'});
              await db.insert('products', {
                'id': 'p',
                'sku': 'MILK',
                'name': 'Milk',
                'active': 1,
                'body': jsonEncode(p.toMap())
              });
              await db.insert(
                  'barcodes', {'barcode': '00123', 'product': 'p', 'unit': 0});
              await db.insert(
                  'stock', {'product': 'p', 'quantity': 10, 'revision': 1});
              await db.insert('ledger', {
                'id': 'old',
                'product': 'p',
                'delta': -1,
                'quantity': 9,
                'body': jsonEncode({
                  'operationId': 'old',
                  'productId': 'p',
                  'kind': 'count',
                  'quantity': 9,
                  'reason': 'Count',
                  'expectedRevision': 1
                })
              });
              await db.insert('outbox', {'id': 'old', 'status': 'pending'});
              for (final feed in ['catalog', 'stock']) {
                await db.insert('cursors', {'feed': feed, 'value': 1});
                await db.insert('sync_state', {'feed': feed, 'has_more': 1});
              }
            }));
    await db.close();
    final store = await InventoryStore.open(databaseFactoryFfi, path,
        merchantId: 'm', branchId: 'b');
    addTearDown(store.close);
    expect((await store.pending()).single.id, 'old');
    expect((await store.search('')).single.quantity, 9);
    expect(await store.stockCursor(), 1);
    expect(await store.hasPendingSync(), isTrue);
    expect(await store.checkout.catalogSequence('p'), isNull);
    await store.checkout.resolveQuote(CatalogChange(1, p));
    expect(await store.checkout.catalogSequence('p'), 1);
    expect((await store.lookupBarcode('00123'))!.unit.priceCentavos, 1250);
    expect(await store.checkout.receipts(), isEmpty);
  });
  test('v4 recovery migration preserves financial ledger and pending receipts',
      () async {
    final dir = await Directory.systemTemp.createTemp('checkout-v4');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/db';
    var store = await InventoryStore.open(databaseFactoryFfi, path,
        merchantId: 'm', branchId: 'b');
    await store.applyCatalog(DeltaPage(
        cursor: 1, hasMore: false, changes: [CatalogChange(1, f.product)]));
    await store.checkout.openShift(f.opening());
    await store.checkout.saveDraft(CheckoutDraft(
        scope: f.scope,
        shiftId: 'shift',
        lines: f.sale().lines,
        frozenSale: f.sale()));
    await store.checkout.completeSale(f.sale());
    await store.close();
    final v4 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(singleInstance: false));
    await v4.execute('DROP TABLE checkout_recovery');
    await v4.execute('PRAGMA user_version=4');
    await v4.close();
    store = await InventoryStore.open(databaseFactoryFfi, path,
        merchantId: 'm', branchId: 'b');
    addTearDown(store.close);
    expect((await store.checkout.receipts()).single.id, 'sale');
    expect(await store.checkout.pendingIntents(), hasLength(2));
    expect((await store.search('')).single.quantity, -1);
    expect(await store.checkout.catalogSequence('p'), 1);
    expect(await store.checkout.unseenReceipt('d', 'c'), isNull);
  });
}
