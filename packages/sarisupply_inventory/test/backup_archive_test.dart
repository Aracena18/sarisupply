import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('BackupArchiveService AES-256-GCM and CSV exports', () {
    late Directory dir;
    late InventoryStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('backup-test-');
      store = await InventoryStore.open(
        databaseFactoryFfi,
        '${dir.path}/db',
        merchantId: 'test_merchant',
        branchId: 'test_branch',
      );
    });

    tearDown(() async {
      await store.close();
      await dir.delete(recursive: true);
    });

    test('Encrypt, export, decrypt, and verify SHA-256 manifest', () async {
      final archive = await BackupArchiveService.exportEncryptedBackup(
        db: store.db,
        merchantId: 'test_merchant',
        branchId: 'test_branch',
        password: 'SuperSecurePassword123!',
      );

      expect(archive.manifest.merchantId, 'test_merchant');
      expect(archive.manifest.branchId, 'test_branch');
      expect(archive.manifest.sha256Hash.isNotEmpty, true);
      expect(archive.ciphertextBase64.isNotEmpty, true);

      // Verify valid archive
      final decrypted = await BackupArchiveService.verifyBackupArchive(
        archive: archive,
        password: 'SuperSecurePassword123!',
      );

      expect(decrypted['merchantId'], 'test_merchant');
      expect(decrypted['branchId'], 'test_branch');

      // Verify wrong passphrase fails
      expect(
        () async => await BackupArchiveService.verifyBackupArchive(
          archive: archive,
          password: 'WrongPassword!',
        ),
        throwsA(isA<StateError>()),
      );

      // Verify JSON serialization round-trip
      final jsonMap = archive.toMap();
      final revived = EncryptedBackupArchive.fromMap(jsonMap);
      expect(revived.manifest.sha256Hash, archive.manifest.sha256Hash);
    });

    test('Tampered ciphertext fails SHA-256 integrity verification', () async {
      final archive = await BackupArchiveService.exportEncryptedBackup(
        db: store.db,
        merchantId: 'test_merchant',
        branchId: 'test_branch',
        password: 'Password123',
      );

      // Create tampered manifest with bogus hash
      final tamperedArchive = EncryptedBackupArchive(
        manifest: ArchiveManifest(
          version: archive.manifest.version,
          merchantId: archive.manifest.merchantId,
          branchId: archive.manifest.branchId,
          createdAt: archive.manifest.createdAt,
          recordCount: archive.manifest.recordCount,
          sha256Hash: 'bogus_tampered_hash_00000000000000000000000000000000',
        ),
        saltBase64: archive.saltBase64,
        nonceBase64: archive.nonceBase64,
        ciphertextBase64: archive.ciphertextBase64,
        macBase64: archive.macBase64,
      );

      expect(
        () async => await BackupArchiveService.verifyBackupArchive(
          archive: tamperedArchive,
          password: 'Password123',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('exportSalesCsv formats RFC-4180 CSV correctly', () {
      const summary = DailySalesSummary(
        date: '2026-10-05',
        branchId: 'branch_1',
        grossSalesCentavos: 10000,
        refundsCentavos: 500,
        transactionCount: 2,
        tenders: TenderBreakdown(
          cashCentavos: 9500,
        ),
      );

      final csv = BackupArchiveService.exportSalesCsv([summary]);

      expect(
        csv.contains(
            'Date,Branch,Gross Sales (PHP),Discounts (PHP),Refunds (PHP),Voids (PHP),Net Sales (PHP),Transactions,Cash (PHP),QR (PHP),Credit (PHP)'),
        true,
      );
      expect(
          csv.contains(
              '2026-10-05,branch_1,100.00,0.00,5.00,0.00,95.00,2,95.00,0.00,0.00'),
          true);
    });

    test('exportInventoryCsv formats inventory valuation CSV correctly', () {
      final report = InventoryValuationReport(
        generatedAt: DateTime.utc(2026, 10, 5),
        branchId: 'branch_1',
        products: const [
          ProductValuationRow(
            productId: 'p1',
            sku: 'COKE',
            name: 'Coca Cola 1.5L',
            unitName: 'bottle',
            physicalQuantity: 20,
            costPriceCentavos: 5000,
            retailPriceCentavos: 6500,
          ),
        ],
      );

      final csv = BackupArchiveService.exportInventoryCsv(report);
      expect(
        csv.contains(
            'SKU,Product Name,Unit,Physical Stock,Unit Cost (PHP),Retail Price (PHP),Total Cost (PHP),Total Retail (PHP),Potential Profit (PHP)'),
        true,
      );
      expect(
          csv.contains(
              'COKE,Coca Cola 1.5L,bottle,20,50.00,65.00,1000.00,1300.00,300.00'),
          true);
    });
  });

  group('InventoryStore Reports & Stock Alerts', () {
    late Directory dir;
    late InventoryStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('inv-reports-');
      store = await InventoryStore.open(
        databaseFactoryFfi,
        '${dir.path}/db',
        merchantId: 'm',
        branchId: 'b',
      );

      final p1 = CatalogProduct(
        id: 'p1',
        sku: 'MILK',
        name: 'Fresh Milk',
        baseUnit: 'carton',
        revision: 1,
        active: true,
        units: [
          CatalogUnit(name: 'carton', factor: 1, priceCentavos: 10000),
        ],
      );

      final p2 = CatalogProduct(
        id: 'p2',
        sku: 'BREAD',
        name: 'Sliced Bread',
        baseUnit: 'loaf',
        revision: 1,
        active: true,
        units: [
          CatalogUnit(name: 'loaf', factor: 1, priceCentavos: 5000),
        ],
      );

      await store.applyCatalog(DeltaPage(
        cursor: 2,
        hasMore: false,
        changes: [
          CatalogChange(1, p1),
          CatalogChange(2, p2),
        ],
      ));

      // Stock for p1 is received (qty = 15)
      await store.recordReceiving(
        operationId: 'rec_1',
        productId: 'p1',
        quantity: 15,
        reason: 'Initial PO',
      );
    });

    tearDown(() async {
      await store.close();
      await dir.delete(recursive: true);
    });

    test(
        'generateInventoryValuation aggregates physical stock and retail values',
        () async {
      final valuation = await store.generateInventoryValuation();

      expect(valuation.branchId, 'b');
      expect(valuation.totalSkus, 2);
      // p1 has 15 in stock, p2 has 0 in stock
      expect(valuation.outOfStockCount, 1); // p2 has 0
      expect(valuation.lowStockCount, 0); // p1 has 15 (> 10)

      final p1Val = valuation.products.firstWhere((p) => p.productId == 'p1');
      expect(p1Val.physicalQuantity, 15);
      expect(p1Val.retailPriceCentavos, 10000);
      expect(p1Val.costPriceCentavos, isNull);
      expect(p1Val.totalRetailValueCentavos, 150000);
      expect(p1Val.totalCostValueCentavos, isNull);
      expect(p1Val.potentialProfitCentavos, isNull);

      // Movement summary reflects receiving
      expect(valuation.movementSummary?.receivedQuantity, 15);
    });

    test('detectStockAlerts flags out-of-stock and low-stock products',
        () async {
      final alerts = await store.detectStockAlerts(lowStockThreshold: 10);

      // p2 is out of stock (qty = 0)
      final oosAlert = alerts.where((a) => a.id == 'out_of_stock_p2');
      expect(oosAlert.isNotEmpty, true);
      expect(oosAlert.first.severity, NotificationSeverity.critical);
      expect(oosAlert.first.category, NotificationCategory.stock);
    });
  });
}
