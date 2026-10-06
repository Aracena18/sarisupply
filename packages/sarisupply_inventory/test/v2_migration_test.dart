import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  for (final hasSyncState in [false, true]) {
    test('version 2 preserves pending work (sync table: $hasSyncState)',
        () async {
      final dir = await Directory.systemTemp.createTemp('inventory-v2-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/v2.db';
      // The two version-2 schemas circulated before sync_state received
      // its own migration. Build fixtures independently of current migrations.
      final db = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 2,
              onCreate: (db, _) async {
                for (final sql in [
                  'CREATE TABLE context(id INTEGER PRIMARY KEY,merchant TEXT,branch TEXT)',
                  'CREATE TABLE products(id TEXT PRIMARY KEY,sku TEXT UNIQUE,name TEXT,active INTEGER,body TEXT)',
                  'CREATE TABLE barcodes(barcode TEXT PRIMARY KEY,product TEXT,unit INTEGER)',
                  'CREATE TABLE stock(product TEXT PRIMARY KEY,quantity INTEGER,revision INTEGER)',
                  'CREATE TABLE ledger(id TEXT PRIMARY KEY,product TEXT,delta INTEGER,body TEXT,reverses TEXT,quantity INTEGER)',
                  'CREATE TABLE outbox(id TEXT PRIMARY KEY,status TEXT,sequence INTEGER,message TEXT)',
                  'CREATE TABLE cursors(feed TEXT PRIMARY KEY,value INTEGER)',
                  "CREATE TRIGGER ledger_no_update BEFORE UPDATE ON ledger BEGIN SELECT RAISE(ABORT, 'Immutable ledger'); END",
                  "CREATE TRIGGER ledger_no_delete BEFORE DELETE ON ledger BEGIN SELECT RAISE(ABORT, 'Immutable ledger'); END",
                ]) {
                  await db.execute(sql);
                }
                await db.insert(
                    'context', {'id': 1, 'merchant': 'm', 'branch': 'b'});
                for (final feed in ['catalog', 'stock']) {
                  await db.insert('cursors', {'feed': feed, 'value': 3});
                }
                final product = CatalogProduct(
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
                          barcode: '00123')
                    ]);
                await db.insert('products', {
                  'id': 'p',
                  'sku': 'MILK',
                  'name': 'Milk',
                  'active': 1,
                  'body': jsonEncode(product.toMap())
                });
                await db.insert('barcodes',
                    {'barcode': '00123', 'product': 'p', 'unit': 0});
                await db.insert(
                    'stock', {'product': 'p', 'quantity': 9, 'revision': 2});
                await db.insert('ledger', {
                  'id': 'pending',
                  'product': 'p',
                  'delta': -2,
                  'quantity': 7,
                  'body': jsonEncode({
                    'operationId': 'pending',
                    'productId': 'p',
                    'quantity': 7,
                    'expectedRevision': 2,
                    'reason': 'Count',
                    'kind': 'count'
                  })
                });
                await db
                    .insert('outbox', {'id': 'pending', 'status': 'pending'});
                if (hasSyncState) {
                  await db.execute(
                      'CREATE TABLE sync_state(feed TEXT PRIMARY KEY,has_more INTEGER NOT NULL)');
                  await db
                      .insert('sync_state', {'feed': 'catalog', 'has_more': 1});
                  await db
                      .insert('sync_state', {'feed': 'stock', 'has_more': 0});
                }
              }));
      await db.close();
      final store = await InventoryStore.open(databaseFactoryFfi, path,
          merchantId: 'm', branchId: 'b');
      addTearDown(store.close);
      expect(await store.hasPendingSync(), hasSyncState);
      expect(await store.catalogCursor(), 3);
      expect(await store.stockCursor(), 3);
      expect((await store.pending()).single.id, 'pending');
      expect((await store.search('Milk')).single.quantity, 7);
      expect((await store.lookupBarcode('00123'))!.unit.priceCentavos, 1250);
      expect(await store.ledgerCount(), 1);
      final inspection = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(singleInstance: false));
      expect(await inspection.getVersion(), 10);
      await expectLater(
          inspection.update('ledger', {'delta': 99}), throwsA(anything));
      await expectLater(inspection.delete('ledger'), throwsA(anything));
      await inspection.close();
    });
  }
}
