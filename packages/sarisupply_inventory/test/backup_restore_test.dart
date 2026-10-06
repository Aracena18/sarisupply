import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Disaster Recovery & Backup Restore Engine', () {
    test('checkDatabaseIntegrity reports healthy status on valid database',
        () async {
      final dir = await Directory.systemTemp.createTemp('sari-integrity-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/test.db';

      final store = await InventoryStore.open(
        databaseFactoryFfi,
        path,
        merchantId: 'merchant-alpha',
        branchId: 'branch-1',
      );
      addTearDown(store.close);

      final report = await store.checkIntegrity();
      expect(report.isHealthy, isTrue);
      expect(report.quickCheckPassed, isTrue);
      expect(report.integrityCheckResult, 'ok');
      expect(report.databaseVersion, 10);
    });

    test('backup, corruption rejection, and full restore into active database',
        () async {
      final dir = await Directory.systemTemp.createTemp('sari-restore-');
      addTearDown(() => dir.delete(recursive: true));
      final path1 = '${dir.path}/store1.db';
      final path2 = '${dir.path}/store2.db';

      // 1. Setup store 1 and insert a product and sale
      final store1 = await InventoryStore.open(
        databaseFactoryFfi,
        path1,
        merchantId: 'merchant-alpha',
        branchId: 'branch-1',
      );

      final product = CatalogProduct(
        id: 'prod-corned-beef',
        sku: 'CB-150',
        name: 'Corned Beef 150g',
        baseUnit: 'can',
        revision: 1,
        active: true,
        units: [
          CatalogUnit(
            name: 'can',
            factor: 1,
            priceCentavos: 4500,
            barcode: '480001',
          ),
        ],
      );

      await store1.db.insert('products', {
        'id': product.id,
        'sku': product.sku,
        'name': product.name,
        'active': 1,
        'body': jsonEncode(product.toMap()),
      });

      await store1.db.insert('stock', {
        'product': product.id,
        'quantity': 50,
        'revision': 1,
      });

      await store1.db.insert('checkout_events', {
        'id': 'sale-001',
        'device': 'dev-1',
        'cashier': 'cashier-1',
        'shift': 'shift-1',
        'ordinal': 1,
        'kind': 'sale',
        'body': jsonEncode({'total': 4500}),
      });

      await store1.db.insert('checkout_sales', {
        'id': 'sale-001',
        'body': jsonEncode({
          'id': 'sale-001',
          'total_centavos': 4500,
        }),
      });

      // 2. Export encrypted backup
      final backup = await store1.exportBackupArchive(password: 'SecureKey99!');
      expect(backup.manifest.recordCount, greaterThanOrEqualTo(1));
      await store1.close();

      // 3. Test wrong password rejection
      expect(
        () => BackupArchiveService.verifyBackupArchive(
          archive: backup,
          password: 'WrongPassword!',
        ),
        throwsA(isA<StateError>()),
      );

      // 4. Open clean store 2 and restore backup
      final store2 = await InventoryStore.open(
        databaseFactoryFfi,
        path2,
        merchantId: 'merchant-alpha',
        branchId: 'branch-1',
      );
      addTearDown(store2.close);

      // Verify store 2 initially empty
      final preCheck = await store2.checkIntegrity();
      expect(preCheck.salesCount, 0);

      // Restore
      final restoreResult = await store2.restoreBackup(
        archive: backup,
        password: 'SecureKey99!',
      );

      expect(restoreResult.success, isTrue);
      expect(restoreResult.salesRestored, 1);
      expect(restoreResult.stockRestored, 1);

      // Verify store 2 now has restored data
      final postCheck = await store2.checkIntegrity();
      expect(postCheck.salesCount, 1);
      expect(postCheck.stockCount, 1);
      expect(postCheck.isHealthy, isTrue);

      final salesQuery = await store2.db.query('checkout_sales');
      expect(salesQuery.first['id'], 'sale-001');
      final salesBody = jsonDecode(salesQuery.first['body'] as String)
          as Map<String, dynamic>;
      expect(salesBody['total_centavos'], 4500);

      final stockQuery = await store2.db.query('stock');
      expect(stockQuery.first['product'], 'prod-corned-beef');
      expect(stockQuery.first['quantity'], 50);
    });
  });
}
