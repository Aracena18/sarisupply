import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common/sqlite_api.dart';

class ArchiveManifest {
  const ArchiveManifest({
    required this.version,
    required this.merchantId,
    required this.branchId,
    required this.createdAt,
    required this.recordCount,
    required this.sha256Hash,
  });

  final int version;
  final String merchantId;
  final String branchId;
  final String createdAt;
  final int recordCount;
  final String sha256Hash;

  Map<String, dynamic> toMap() => {
        'version': version,
        'merchantId': merchantId,
        'branchId': branchId,
        'createdAt': createdAt,
        'recordCount': recordCount,
        'sha256Hash': sha256Hash,
      };

  factory ArchiveManifest.fromMap(Map<String, dynamic> map) => ArchiveManifest(
        version: (map['version'] as num?)?.toInt() ?? 1,
        merchantId: map['merchantId'] as String? ?? '',
        branchId: map['branchId'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
        recordCount: (map['recordCount'] as num?)?.toInt() ?? 0,
        sha256Hash: map['sha256Hash'] as String? ?? '',
      );
}

class EncryptedBackupArchive {
  const EncryptedBackupArchive({
    required this.manifest,
    required this.saltBase64,
    required this.nonceBase64,
    required this.ciphertextBase64,
    required this.macBase64,
  });

  final ArchiveManifest manifest;
  final String saltBase64;
  final String nonceBase64;
  final String ciphertextBase64;
  final String macBase64;

  Map<String, dynamic> toMap() => {
        'manifest': manifest.toMap(),
        'salt': saltBase64,
        'nonce': nonceBase64,
        'ciphertext': ciphertextBase64,
        'mac': macBase64,
      };

  String toJson() => jsonEncode(toMap());

  factory EncryptedBackupArchive.fromMap(Map<String, dynamic> map) =>
      EncryptedBackupArchive(
        manifest: ArchiveManifest.fromMap(
            Map<String, dynamic>.from(map['manifest'] as Map)),
        saltBase64: map['salt'] as String? ?? '',
        nonceBase64: map['nonce'] as String? ?? '',
        ciphertextBase64: map['ciphertext'] as String? ?? '',
        macBase64: map['mac'] as String? ?? '',
      );

  factory EncryptedBackupArchive.fromJson(String source) =>
      EncryptedBackupArchive.fromMap(
          jsonDecode(source) as Map<String, dynamic>);
}

class DatabaseIntegrityReport {
  const DatabaseIntegrityReport({
    required this.isHealthy,
    required this.quickCheckPassed,
    required this.integrityCheckResult,
    required this.productCount,
    required this.stockCount,
    required this.salesCount,
    required this.ledgerCount,
    required this.pendingOutboxCount,
    this.blockedOutboxCount = 0,
    required this.databaseVersion,
    required this.checkedAt,
  });

  final bool isHealthy;
  final bool quickCheckPassed;
  final String integrityCheckResult;
  final int productCount;
  final int stockCount;
  final int salesCount;
  final int ledgerCount;
  final int pendingOutboxCount;
  final int blockedOutboxCount;
  final int databaseVersion;
  final DateTime checkedAt;

  Map<String, dynamic> toMap() => {
        'isHealthy': isHealthy,
        'quickCheckPassed': quickCheckPassed,
        'integrityCheckResult': integrityCheckResult,
        'productCount': productCount,
        'stockCount': stockCount,
        'salesCount': salesCount,
        'ledgerCount': ledgerCount,
        'pendingOutboxCount': pendingOutboxCount,
        'blockedOutboxCount': blockedOutboxCount,
        'databaseVersion': databaseVersion,
        'checkedAt': checkedAt.toIso8601String(),
      };
}

class RestoreResult {
  const RestoreResult({
    required this.success,
    required this.message,
    required this.salesRestored,
    required this.eventsRestored,
    required this.shiftsRestored,
    required this.ledgerRestored,
    required this.stockRestored,
    required this.restoredAt,
  });

  final bool success;
  final String message;
  final int salesRestored;
  final int eventsRestored;
  final int shiftsRestored;
  final int ledgerRestored;
  final int stockRestored;
  final DateTime restoredAt;

  Map<String, dynamic> toMap() => {
        'success': success,
        'message': message,
        'salesRestored': salesRestored,
        'eventsRestored': eventsRestored,
        'shiftsRestored': shiftsRestored,
        'ledgerRestored': ledgerRestored,
        'stockRestored': stockRestored,
        'restoredAt': restoredAt.toIso8601String(),
      };
}

class BackupArchiveService {
  static final _kdf = Pbkdf2.hmacSha256(iterations: 100000, bits: 256);
  static final _legacyKdf = Pbkdf2.hmacSha256(iterations: 10000, bits: 256);
  static String _table(String value) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value)) {
      throw StateError('Invalid archive table');
    }
    return value;
  }

  static Future<
      List<
          Map<String, Object?>>> _schema(DatabaseExecutor db) => db.rawQuery(
      "SELECT name,sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY rowid");
  static final _aesGcm = AesGcm.with256bits();

  static List<int> _generateRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Exports local database historical tables into an AES-256-GCM encrypted backup
  /// with a tamper-evident SHA-256 plaintext integrity manifest.
  static Future<EncryptedBackupArchive> exportEncryptedBackup({
    required Database db,
    required String merchantId,
    required String branchId,
    required String password,
  }) async {
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters');
    }

    // One database transaction produces a consistent snapshot, including all
    // pending work, cursors, drafts, credit, transfers and delivery proofs.
    final payload = await db.transaction((tx) async {
      final tables = <String, Object?>{};
      for (final row in await _schema(tx)) {
        final name = _table(row['name'] as String);
        tables[name] = await tx.query(name);
      }
      final context = (tables['context'] as List).single as Map;
      if (context['merchant'] != merchantId || context['branch'] != branchId) {
        throw StateError('Backup scope mismatch');
      }
      return <String, Object?>{
        'merchantId': merchantId,
        'branchId': branchId,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'schemaVersion': await tx.getVersion(),
        'tables': tables,
      };
    });
    final tables = payload['tables'] as Map<String, Object?>;
    final recordCount =
        tables.values.fold<int>(0, (n, rows) => n + (rows as List).length);
    final jsonBytes = utf8.encode(jsonEncode(payload));
    final sha256Hex = sha256.convert(jsonBytes).toString();

    // 2. Derive encryption key using PBKDF2
    final salt = _generateRandomBytes(16);
    final secretKey = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    // 3. Encrypt payload with AES-256-GCM
    final nonce = _generateRandomBytes(12);
    final secretBox = await _aesGcm.encrypt(
      jsonBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final manifest = ArchiveManifest(
      version: 2,
      merchantId: merchantId,
      branchId: branchId,
      createdAt: DateTime.now().toIso8601String(),
      recordCount: recordCount,
      sha256Hash: sha256Hex,
    );

    return EncryptedBackupArchive(
      manifest: manifest,
      saltBase64: base64Encode(salt),
      nonceBase64: base64Encode(nonce),
      ciphertextBase64: base64Encode(secretBox.cipherText),
      macBase64: base64Encode(secretBox.mac.bytes),
    );
  }

  /// Verifies the archive password and proves SHA-256 integrity match against manifest.
  /// Returns the decrypted raw map data upon success.
  static Future<Map<String, dynamic>> verifyBackupArchive({
    required EncryptedBackupArchive archive,
    required String password,
  }) async {
    if (![1, 2].contains(archive.manifest.version)) {
      throw StateError('Unsupported archive version');
    }
    final salt = base64Decode(archive.saltBase64);
    final nonce = base64Decode(archive.nonceBase64);
    final ciphertext = base64Decode(archive.ciphertextBase64);
    final macBytes = base64Decode(archive.macBase64);

    if (salt.length != 16 || nonce.length != 12 || macBytes.length != 16) {
      throw StateError('Invalid archive encryption metadata');
    }
    final secretKey = await (archive.manifest.version == 1 ? _legacyKdf : _kdf)
        .deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final Uint8List decryptedBytes;
    try {
      final decryptedList = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      decryptedBytes = Uint8List.fromList(decryptedList);
    } catch (_) {
      throw StateError('Invalid password or corrupted backup file');
    }

    // Verify SHA-256 hash
    final computedSha256 = sha256.convert(decryptedBytes).toString();
    if (computedSha256 != archive.manifest.sha256Hash) {
      throw StateError(
        'Integrity check failed: Manifest SHA-256 mismatch (possible tampering)',
      );
    }

    final data =
        jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
    if (data['merchantId'] != archive.manifest.merchantId ||
        data['branchId'] != archive.manifest.branchId) {
      throw StateError('Archive scope metadata does not match encrypted data');
    }
    if (archive.manifest.version == 2) {
      final tables = data['tables'] as Map<String, dynamic>;
      final count =
          tables.values.fold<int>(0, (n, rows) => n + (rows as List).length);
      if (count != archive.manifest.recordCount) {
        throw StateError('Archive record count mismatch');
      }
    }
    return data;
  }

  static String _csvCell(Object value) {
    final text = value.toString();
    return text.contains(RegExp('[,"\r\n]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  /// Generates standard CSV export for sales summaries compatible with Excel/Sheets.
  static String exportSalesCsv(List<DailySalesSummary> summaries) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Date,Branch,Gross Sales (PHP),Discounts (PHP),Refunds (PHP),Voids (PHP),Net Sales (PHP),Transactions,Cash (PHP),QR (PHP),Credit (PHP)',
    );
    for (final s in summaries) {
      buffer.writeln([
        s.date,
        s.branchId,
        (s.grossSalesCentavos / 100).toStringAsFixed(2),
        (s.discountsCentavos / 100).toStringAsFixed(2),
        (s.refundsCentavos / 100).toStringAsFixed(2),
        (s.voidsCentavos / 100).toStringAsFixed(2),
        (s.netSalesCentavos / 100).toStringAsFixed(2),
        s.transactionCount,
        (s.tenders.cashCentavos / 100).toStringAsFixed(2),
        (s.tenders.qrCentavos / 100).toStringAsFixed(2),
        (s.tenders.creditCentavos / 100).toStringAsFixed(2),
      ].map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  /// Generates standard CSV export for inventory valuation compatible with Excel/Sheets.
  static String exportInventoryCsv(InventoryValuationReport report) {
    final buffer = StringBuffer();
    buffer.writeln(
      'SKU,Product Name,Unit,Physical Stock,Unit Cost (PHP),Retail Price (PHP),Total Cost (PHP),Total Retail (PHP),Potential Profit (PHP)',
    );
    for (final p in report.products) {
      final escapedName = p.name;
      buffer.writeln([
        p.sku,
        escapedName,
        p.unitName,
        p.physicalQuantity,
        p.costPriceCentavos == null
            ? ''
            : (p.costPriceCentavos! / 100).toStringAsFixed(2),
        (p.retailPriceCentavos / 100).toStringAsFixed(2),
        p.totalCostValueCentavos == null
            ? ''
            : (p.totalCostValueCentavos! / 100).toStringAsFixed(2),
        (p.totalRetailValueCentavos / 100).toStringAsFixed(2),
        p.potentialProfitCentavos == null
            ? ''
            : (p.potentialProfitCentavos! / 100).toStringAsFixed(2),
      ].map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  /// Restores historical data from an encrypted backup archive into the active database.
  /// Validates password, SHA-256 integrity hash, and matches merchant/branch if expected.
  static Future<RestoreResult> restoreAndVerifyBackup({
    required Database db,
    required DatabaseFactory factory,
    required EncryptedBackupArchive archive,
    required String password,
    String? expectedMerchantId,
    String? expectedBranchId,
  }) async {
    final data =
        await verifyBackupArchive(archive: archive, password: password);
    if (archive.manifest.version != 2) {
      throw StateError(
          'Legacy archives contain incomplete state. Export a complete backup before restoration.');
    }
    if ((expectedMerchantId != null &&
            data['merchantId'] != expectedMerchantId) ||
        (expectedBranchId != null && data['branchId'] != expectedBranchId)) {
      throw StateError('Backup belongs to another store or branch');
    }
    final schema = await _schema(db);
    final tables = Map<String, dynamic>.from(data['tables'] as Map);
    final names = schema.map((r) => _table(r['name'] as String)).toSet();
    if (names.length != tables.length ||
        !names.containsAll(tables.keys) ||
        data['schemaVersion'] != await db.getVersion()) {
      throw StateError(
          'Backup database schema does not match this application');
    }
    // Validate all constraints in an isolated database before touching live state.
    final staged = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    try {
      for (final table in schema) {
        await staged.execute(table['sql'] as String);
      }
      await staged.transaction((tx) async {
        for (final name in names) {
          for (final raw in tables[name] as List) {
            await tx.insert(name, Map<String, Object?>.from(raw as Map));
          }
        }
      });
      if ((await staged.rawQuery('PRAGMA foreign_key_check')).isNotEmpty ||
          (await staged.rawQuery('PRAGMA integrity_check'))
                  .single
                  .values
                  .single !=
              'ok') {
        throw StateError('Backup records fail database validation');
      }
      final scope = (await staged.query('context')).single;
      if (scope['merchant'] != data['merchantId'] ||
          scope['branch'] != data['branchId']) {
        throw StateError('Backup context is inconsistent');
      }
      await db.transaction((tx) async {
        // Replacement cannot silently discard newer work. Restore into an empty
        // recovery workspace; the original file remains the rollback copy.
        for (final name
            in names.difference({'context', 'cursors', 'sync_state'})) {
          if ((await tx.query(name, limit: 1)).isNotEmpty) {
            throw StateError(
                'Restore requires an empty recovery workspace. Existing business data is preserved.');
          }
        }
        await tx.execute('PRAGMA defer_foreign_keys = ON');
        for (final name in names) {
          for (final raw in tables[name] as List) {
            await tx.insert(name, Map<String, Object?>.from(raw as Map),
                conflictAlgorithm: name == 'context'
                    ? ConflictAlgorithm.ignore
                    : {'cursors', 'sync_state'}.contains(name)
                        ? ConflictAlgorithm.replace
                        : ConflictAlgorithm.abort);
          }
        }
        if ((await tx.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
          throw StateError('Restored records fail foreign key validation');
        }
      });
    } finally {
      await staged.close();
    }
    int count(String name) => (tables[name] as List).length;
    return RestoreResult(
        success: true,
        message:
            'Complete backup restored, including pending synchronization records.',
        salesRestored: count('checkout_sales'),
        eventsRestored: count('checkout_events'),
        shiftsRestored: count('checkout_shifts'),
        ledgerRestored: count('ledger'),
        stockRestored: count('stock'),
        restoredAt: DateTime.now());
  }

  /// Evaluates SQLite database integrity and collects row counts.
  static Future<DatabaseIntegrityReport> checkDatabaseIntegrity(
      Database db) async {
    // 1. Quick check
    final quickCheck = await db.rawQuery('PRAGMA quick_check');
    final quickResult = quickCheck.isNotEmpty
        ? (quickCheck.first.values.first?.toString() ?? 'unknown')
        : 'unknown';
    final quickPassed = quickResult.toLowerCase() == 'ok';

    // 2. Full integrity check
    final integrityCheck = await db.rawQuery('PRAGMA integrity_check');
    final integrityResult = integrityCheck.isNotEmpty
        ? (integrityCheck.first.values.first?.toString() ?? 'unknown')
        : 'unknown';
    final integrityPassed = integrityResult.toLowerCase() == 'ok';

    // 3. Row counts
    var productCount = 0;
    try {
      final res = await db.rawQuery('SELECT COUNT(*) as c FROM products');
      productCount = (res.first['c'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    var stockCount = 0;
    try {
      final res = await db.rawQuery('SELECT COUNT(*) as c FROM stock');
      stockCount = (res.first['c'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    var salesCount = 0;
    try {
      final res = await db.rawQuery('SELECT COUNT(*) as c FROM checkout_sales');
      salesCount = (res.first['c'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    var ledgerCount = 0;
    try {
      final res = await db.rawQuery('SELECT COUNT(*) as c FROM ledger');
      ledgerCount = (res.first['c'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    var pendingOutboxCount = 0;
    var blockedOutboxCount = 0;
    for (final table in [
      'outbox',
      'checkout_outbox',
      'delivery_outbox',
      'procurement_outbox'
    ]) {
      final rows = await db.rawQuery(
          "SELECT COUNT(*) AS c, SUM(CASE WHEN status IN ('blocked','conflict') THEN 1 ELSE 0 END) AS blocked FROM $table WHERE status IN ('pending','blocked','conflict')");
      pendingOutboxCount += (rows.single['c'] as int);
      blockedOutboxCount += (rows.single['blocked'] as int?) ?? 0;
    }

    var databaseVersion = 0;
    try {
      final res = await db.rawQuery('PRAGMA user_version');
      databaseVersion = (res.first.values.first as num?)?.toInt() ?? 0;
    } catch (_) {}

    return DatabaseIntegrityReport(
      isHealthy: quickPassed && integrityPassed,
      quickCheckPassed: quickPassed,
      integrityCheckResult: integrityResult,
      productCount: productCount,
      stockCount: stockCount,
      salesCount: salesCount,
      ledgerCount: ledgerCount,
      pendingOutboxCount: pendingOutboxCount,
      blockedOutboxCount: blockedOutboxCount,
      databaseVersion: databaseVersion,
      checkedAt: DateTime.now(),
    );
  }
}
