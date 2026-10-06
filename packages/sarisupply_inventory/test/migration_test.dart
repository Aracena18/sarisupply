import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test('version 1 database migrates pending stock without losing history',
      () async {
    final dir = await Directory.systemTemp.createTemp('inventory-migration-');
    final path = '${dir.path}/v1.db';
    final db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, v) async {
              for (final sql in [
                'CREATE TABLE context(id INTEGER PRIMARY KEY,merchant TEXT,branch TEXT)',
                'CREATE TABLE products(id TEXT PRIMARY KEY,sku TEXT UNIQUE,name TEXT,active INTEGER,body TEXT)',
                'CREATE TABLE barcodes(barcode TEXT PRIMARY KEY,product TEXT,unit INTEGER)',
                'CREATE TABLE stock(product TEXT PRIMARY KEY,quantity INTEGER,revision INTEGER)',
                'CREATE TABLE ledger(id TEXT PRIMARY KEY,product TEXT,delta INTEGER,body TEXT,reverses TEXT)',
                'CREATE TABLE outbox(id TEXT PRIMARY KEY,status TEXT,sequence INTEGER,message TEXT)',
                'CREATE TABLE cursors(feed TEXT PRIMARY KEY,value INTEGER)',
              ]) {
                await db.execute(sql);
              }
              await db
                  .insert('context', {'id': 1, 'merchant': 'm', 'branch': 'b'});
              for (final feed in ['catalog', 'stock']) {
                await db.insert('cursors', {'feed': feed, 'value': 0});
              }
              await db.insert('ledger', {
                'id': 'old',
                'product': 'p',
                'delta': 7,
                'body': jsonEncode({
                  'operationId': 'old',
                  'productId': 'p',
                  'quantity': 7,
                  'expectedRevision': 0,
                  'reason': 'Opening',
                  'kind': 'opening'
                })
              });
              await db.insert('outbox', {'id': 'old', 'status': 'pending'});
            }));
    await db.close();
    final store = await InventoryStore.open(databaseFactoryFfi, path,
        merchantId: 'm', branchId: 'b');
    expect((await store.pending()).single.quantity, 7);
    expect(await store.ledgerCount(), 1);
    final connection = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(singleInstance: false));
    expect((await connection.query('ledger')).single['quantity'], 7);
    await expectLater(
        connection.update('ledger', {'delta': 999}), throwsA(anything));
    await expectLater(connection.delete('ledger'), throwsA(anything));
    await connection.close();
    await store.close();
    await dir.delete(recursive: true);
  });
}
