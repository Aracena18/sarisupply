import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'archival/backup_archive_service.dart';
part 'checkout_store.dart';

final class InventoryRow {
  const InventoryRow(
      this.product, this.quantity, this.revision, this.unsettled);
  final CatalogProduct product;
  final int quantity, revision, unsettled;
}

final class BarcodeMatch {
  const BarcodeMatch(this.product, this.unit);
  final CatalogProduct product;
  final CatalogUnit unit;
}

final class InventoryStore {
  InventoryStore._(this._db, this._factory, this.merchantId, this.branchId);
  final DatabaseFactory _factory;
  final Database _db;
  Database get db => _db;
  final String merchantId, branchId;
  static Future<InventoryStore> open(DatabaseFactory factory, String path,
      {required String merchantId, required String branchId}) async {
    final db = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 10,
            singleInstance: false,
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys = ON');
              await db.execute('PRAGMA synchronous = FULL');
            },
            onCreate: (db, version) async {
              await _v1(db);
              await _v2(db);
              await _v3(db);
              await CheckoutStore.migrate(db);
              await CheckoutStore.migrateRecovery(db);
              await _v6(db);
              await _v7(db);
              await _v8(db);
              await _v9(db);
              await _v10(db);
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion < 2) await _v2(db);
              if (oldVersion < 3) await _v3(db);
              if (oldVersion < 4) await CheckoutStore.migrate(db);
              if (oldVersion < 5) await CheckoutStore.migrateRecovery(db);
              if (oldVersion < 6) await _v6(db);
              if (oldVersion < 7) await _v7(db);
              if (oldVersion < 8) await _v8(db);
              if (oldVersion < 9) await _v9(db);
              if (oldVersion < 10) await _v10(db);
            }));
    try {
      await db.transaction((tx) async {
        final rows = await tx.query('context');
        if (rows.isEmpty) {
          await tx.insert(
              'context', {'id': 1, 'merchant': merchantId, 'branch': branchId});
        } else if (rows.single['merchant'] != merchantId ||
            rows.single['branch'] != branchId) {
          throw StateError('Inventory scope mismatch');
        }
      });
      return InventoryStore._(db, factory, merchantId, branchId);
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  static Future<void> _v1(DatabaseExecutor db) async {
    await db.execute(
        'CREATE TABLE context (id INTEGER PRIMARY KEY CHECK(id=1), merchant TEXT NOT NULL, branch TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE products (id TEXT PRIMARY KEY, sku TEXT NOT NULL UNIQUE, name TEXT NOT NULL, active INTEGER NOT NULL, body TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE barcodes (barcode TEXT PRIMARY KEY, product TEXT NOT NULL REFERENCES products(id), unit INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE stock (product TEXT PRIMARY KEY, quantity INTEGER NOT NULL, revision INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE ledger (id TEXT PRIMARY KEY, product TEXT NOT NULL REFERENCES products(id), delta INTEGER NOT NULL, body TEXT NOT NULL, reverses TEXT)');
    await db.execute(
        "CREATE TABLE outbox (id TEXT PRIMARY KEY REFERENCES ledger(id), status TEXT NOT NULL DEFAULT 'pending', sequence INTEGER, message TEXT)");
    await db.execute(
        'CREATE TABLE cursors (feed TEXT PRIMARY KEY, value INTEGER NOT NULL)');
    await db.insert('cursors', {'feed': 'catalog', 'value': 0});
    await db.insert('cursors', {'feed': 'stock', 'value': 0});
  }

  static Future<void> _v2(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE ledger ADD COLUMN quantity INTEGER');
    final movements = await db.query('ledger');
    for (final row in movements) {
      final body = jsonDecode(row['body'] as String) as Map;
      await db.update('ledger', {'quantity': body['quantity']},
          where: 'id=?', whereArgs: [row['id']]);
    }
    await db
        .execute('CREATE INDEX products_name ON products(name COLLATE NOCASE)');
    await db.execute('CREATE INDEX ledger_product ON ledger(product)');
    await db.execute('CREATE INDEX outbox_status ON outbox(status)');
    // Business history is append-only, including locally withdrawn drafts.
    await db.execute(
        "CREATE TRIGGER ledger_no_update BEFORE UPDATE ON ledger BEGIN SELECT RAISE(ABORT, 'Immutable ledger'); END");
    await db.execute(
        "CREATE TRIGGER ledger_no_delete BEFORE DELETE ON ledger BEGIN SELECT RAISE(ABORT, 'Immutable ledger'); END");
  }

  static Future<void> _v3(DatabaseExecutor db) async {
    // Some version-2 files already contain this table. Preserve their flags;
    // files created before that change need the missing table and feed rows.
    await db.execute(
        'CREATE TABLE IF NOT EXISTS sync_state (feed TEXT PRIMARY KEY, has_more INTEGER NOT NULL)');
    for (final feed in ['catalog', 'stock']) {
      await db.insert('sync_state', {'feed': feed, 'has_more': 0},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _v6(DatabaseExecutor db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS batches (id TEXT PRIMARY KEY, product TEXT NOT NULL REFERENCES products(id), batch_number TEXT NOT NULL, expiry_date TEXT NOT NULL, quantity INTEGER NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS batches_product ON batches(product)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS batches_expiry ON batches(expiry_date)');

    await db.execute(
        'CREATE TABLE IF NOT EXISTS transfers (id TEXT PRIMARY KEY, source_branch TEXT NOT NULL, destination_branch TEXT NOT NULL, status TEXT NOT NULL, body TEXT NOT NULL, occurred_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS transfers_status ON transfers(status)');

    await db.execute(
        'CREATE TABLE IF NOT EXISTS checkout_refunds (id TEXT PRIMARY KEY REFERENCES checkout_events(id), original_sale TEXT NOT NULL REFERENCES checkout_sales(id), body TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS refund_stock (refund TEXT NOT NULL REFERENCES checkout_refunds(id), product TEXT NOT NULL REFERENCES products(id), delta INTEGER NOT NULL, PRIMARY KEY(refund, product))');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS refund_stock_product ON refund_stock(product)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS checkout_voids (id TEXT PRIMARY KEY REFERENCES checkout_events(id), original_sale TEXT NOT NULL UNIQUE REFERENCES checkout_sales(id), body TEXT NOT NULL)');

    await db.execute(
        'CREATE TABLE IF NOT EXISTS customers (id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT NOT NULL, credit_limit INTEGER NOT NULL, balance INTEGER NOT NULL, active INTEGER NOT NULL)');

    await db.execute(
        'CREATE TABLE IF NOT EXISTS credit_grants (id TEXT PRIMARY KEY, customer_id TEXT NOT NULL REFERENCES customers(id), device_id TEXT NOT NULL, allowed INTEGER NOT NULL, used INTEGER NOT NULL, expires_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS credit_grants_customer ON credit_grants(customer_id)');

    await db.execute(
        'CREATE TABLE IF NOT EXISTS debt_repayments (id TEXT PRIMARY KEY, customer_id TEXT NOT NULL REFERENCES customers(id), amount INTEGER NOT NULL, tender_kind TEXT NOT NULL, shift TEXT NOT NULL, cashier TEXT NOT NULL, reference TEXT NOT NULL, notes TEXT NOT NULL, occurred_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS debt_repayments_customer ON debt_repayments(customer_id)');

    for (final table in [
      'checkout_refunds',
      'refund_stock',
      'checkout_voids',
      'debt_repayments',
    ]) {
      for (final action in ['UPDATE', 'DELETE']) {
        await db.execute(
            "CREATE TRIGGER IF NOT EXISTS ${table}_no_${action.toLowerCase()} BEFORE $action ON $table BEGIN SELECT RAISE(ABORT,'Immutable finance'); END");
      }
    }
  }

  static Future<void> _v7(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        contact_person TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        address TEXT NOT NULL,
        lead_time_days INTEGER NOT NULL,
        active INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS suppliers_name ON suppliers(name COLLATE NOCASE)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_orders (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL REFERENCES suppliers(id),
        supplier_name TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        status TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        expected_delivery_date TEXT,
        notes TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS po_supplier ON purchase_orders(supplier_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS po_status ON purchase_orders(status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        address TEXT NOT NULL,
        active INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouse_stock (
        warehouse_id TEXT NOT NULL REFERENCES warehouses(id),
        product_id TEXT NOT NULL REFERENCES products(id),
        physical_quantity INTEGER NOT NULL,
        reserved_quantity INTEGER NOT NULL,
        PRIMARY KEY (warehouse_id, product_id)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS wh_stock_product ON warehouse_stock(product_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restock_proposals (
        id TEXT PRIMARY KEY,
        branch_id TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        status TEXT NOT NULL,
        body TEXT NOT NULL,
        requested_at TEXT NOT NULL,
        reviewed_at TEXT,
        reviewed_by TEXT,
        rejection_reason TEXT,
        notes TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS restock_status ON restock_proposals(status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS restock_branch ON restock_proposals(branch_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pick_lists (
        id TEXT PRIMARY KEY,
        restock_order_id TEXT NOT NULL REFERENCES restock_proposals(id),
        warehouse_id TEXT NOT NULL,
        picker_id TEXT,
        completed INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS package_manifests (
        id TEXT PRIMARY KEY,
        restock_order_id TEXT NOT NULL REFERENCES restock_proposals(id),
        package_code TEXT NOT NULL,
        total_items INTEGER NOT NULL,
        seal_notes TEXT NOT NULL,
        packed_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _v8(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_runs (
        id TEXT PRIMARY KEY,
        driver_id TEXT NOT NULL,
        driver_name TEXT NOT NULL,
        vehicle_info TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        status TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS delivery_runs_driver ON delivery_runs(driver_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS delivery_runs_status ON delivery_runs(status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_stops (
        id TEXT PRIMARY KEY,
        run_id TEXT NOT NULL REFERENCES delivery_runs(id),
        sequence INTEGER NOT NULL,
        destination_id TEXT NOT NULL,
        destination_name TEXT NOT NULL,
        destination_address TEXT NOT NULL,
        status TEXT NOT NULL,
        body TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS delivery_stops_run ON delivery_stops(run_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS delivery_stops_status ON delivery_stops(status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_stop_items (
        id TEXT PRIMARY KEY,
        stop_id TEXT NOT NULL REFERENCES delivery_stops(id),
        product_id TEXT NOT NULL REFERENCES products(id),
        quantity_ordered INTEGER NOT NULL,
        quantity_delivered INTEGER NOT NULL,
        quantity_returned INTEGER NOT NULL,
        return_reason TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS stop_items_stop ON delivery_stop_items(stop_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_proofs (
        id TEXT PRIMARY KEY,
        stop_id TEXT NOT NULL UNIQUE REFERENCES delivery_stops(id),
        recipient_name TEXT NOT NULL,
        recipient_role TEXT NOT NULL,
        signature_svg TEXT NOT NULL,
        cash_collected_centavos INTEGER NOT NULL,
        delivered_at TEXT NOT NULL,
        body TEXT NOT NULL
      )
    ''');
  }

  CheckoutStore get checkout => CheckoutStore._(this);
  static Future<void> _v10(DatabaseExecutor db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS procurement_outbox(id TEXT PRIMARY KEY,command TEXT NOT NULL,payload TEXT NOT NULL,status TEXT NOT NULL,message TEXT)');
  }

  Future<void> _queueProcurement(
      DatabaseExecutor tx, String command, Map<String, Object?> payload) async {
    final body = jsonEncode({'merchantId': merchantId, ...payload});
    final id = sha256.convert(utf8.encode('$command:$body')).toString();
    await tx.insert('procurement_outbox',
        {'id': id, 'command': command, 'payload': body, 'status': 'pending'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, Object?>>> pendingProcurement() =>
      _db.query('procurement_outbox',
          where: "status IN ('pending','blocked')",
          orderBy: 'rowid',
          limit: 20);

  Future<void> applyProcurementWorkspace(
          String kind, List<Map<String, dynamic>> records,
          {String? warehouseId}) =>
      _db.transaction((tx) async {
        final pending = await tx.query('procurement_outbox',
            where: "status IN ('pending','blocked')", limit: 1);
        if (pending.isNotEmpty) {
          return; // Keep tentative projections until commands settle.
        }
        for (final record in records) {
          if (kind == 'purchaseOrders') {
            final po = PurchaseOrder.fromMap(record);
            await tx.insert(
                'purchase_orders',
                {
                  'id': po.id,
                  'supplier_id': po.supplierId,
                  'supplier_name': po.supplierName,
                  'warehouse_id': po.warehouseId,
                  'status': po.status.name,
                  'body': jsonEncode(po.toMap()),
                  'created_at': po.createdAt.toIso8601String(),
                  'expected_delivery_date':
                      po.expectedDeliveryDate?.toIso8601String(),
                  'notes': po.notes
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
          } else if (kind == 'restockProposals') {
            final proposal = RestockProposal.fromMap(record);
            await tx.insert(
                'restock_proposals',
                {
                  'id': proposal.id,
                  'branch_id': proposal.branchId,
                  'warehouse_id': proposal.warehouseId,
                  'status': proposal.status.name,
                  'body': jsonEncode(proposal.toMap()),
                  'requested_at': proposal.requestedAt.toIso8601String(),
                  'reviewed_at': proposal.reviewedAt?.toIso8601String(),
                  'reviewed_by': proposal.reviewedBy,
                  'rejection_reason': proposal.rejectionReason,
                  'notes': proposal.notes
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
          } else if (kind == 'warehouses') {
            final wh = Warehouse.fromMap(record);
            await tx.insert(
                'warehouses',
                {
                  'id': wh.id,
                  'name': wh.name,
                  'code': wh.code,
                  'address': wh.address,
                  'active': wh.active ? 1 : 0
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
          } else if (kind == 'warehouseStock' && warehouseId != null) {
            final stock = WarehouseStock.fromMap({
              ...record,
              'warehouseId': warehouseId,
              'productId': record['productId'] ?? record['id']
            });
            await tx.insert(
                'warehouse_stock',
                {
                  'warehouse_id': stock.warehouseId,
                  'product_id': stock.productId,
                  'physical_quantity': stock.physicalQuantity,
                  'reserved_quantity': stock.reservedQuantity
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            throw ArgumentError('Invalid purchasing snapshot');
          }
        }
      });

  Future<int> synchronizeProcurement(
      Future<Map<String, Object?>> Function(
              String command, Map<String, Object?> payload)
          send) async {
    final operations = await pendingProcurement();
    for (final operation in operations) {
      if (operation['status'] == 'blocked') break;
      final payload = Map<String, Object?>.from(
          jsonDecode(operation['payload'] as String) as Map);
      final result = await send(operation['command'] as String,
          {...payload, 'queueId': operation['id']});
      if (result['operationId'] != operation['id'] ||
          !['accepted', 'blocked'].contains(result['status'])) {
        throw const FormatException('Invalid procurement acknowledgement');
      }
      await _db.update('procurement_outbox',
          {'status': result['status'], 'message': result['message']},
          where: 'id=?', whereArgs: [operation['id']]);
      if (result['status'] == 'blocked') break;
    }
    return (await pendingProcurement()).length;
  }

  static Future<void> _v9(DatabaseExecutor db) async {
    final creditColumns = await db.rawQuery('PRAGMA table_info(credit_grants)');
    if (!creditColumns.any((column) => column['name'] == 'authoritative')) {
      await db.execute(
          'ALTER TABLE credit_grants ADD COLUMN authoritative INTEGER NOT NULL DEFAULT 0');
    }
    await db.execute(
        'CREATE TABLE IF NOT EXISTS delivery_outbox(id TEXT PRIMARY KEY,run TEXT NOT NULL,stop TEXT NOT NULL,kind TEXT NOT NULL,payload TEXT NOT NULL,status TEXT NOT NULL)');
    for (final row in await db.query('delivery_runs')) {
      final run = DeliveryRun.fromMap(
          Map<String, dynamic>.from(jsonDecode(row['body'] as String) as Map));
      for (final stop in run.stops) {
        if (stop.proof?.offlineCreated == true) {
          await db.insert(
              'delivery_outbox',
              {
                'id': stop.proof!.id,
                'run': run.id,
                'stop': stop.id,
                'kind': 'proof',
                'payload': jsonEncode({
                  'proof': stop.proof!.toMap(),
                  'items': stop.items.map((i) => i.toMap()).toList()
                }),
                'status': 'pending'
              },
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }
  }

  Future<List<Map<String, Object?>>> pendingDeliveries() =>
      _db.query('delivery_outbox',
          where: "status='pending'", orderBy: 'rowid', limit: 50);
  Future<void> acknowledgeDelivery(String id) async {
    await _db.update('delivery_outbox', {'status': 'accepted'},
        where: 'id=?', whereArgs: [id]);
  }

  Future<bool> hasPendingDelivery(String runId) async =>
      (await _db.query('delivery_outbox',
              where: "run=? AND status='pending'",
              whereArgs: [runId],
              limit: 1))
          .isNotEmpty;

  Future<void> close() => _db.close();
  Future<int> _cursor(DatabaseExecutor db, String feed) async =>
      (await db.query('cursors', where: 'feed=?', whereArgs: [feed]))
          .single['value'] as int;
  Future<int> catalogCursor() => _cursor(_db, 'catalog');
  Future<int> stockCursor() => _cursor(_db, 'stock');
  Future<bool> hasPendingFeed(String feed) async =>
      ((await _db.query('sync_state', where: 'feed=?', whereArgs: [feed]))
          .single['has_more'] as int) ==
      1;
  Future<bool> hasPendingSync() async =>
      await hasPendingFeed('catalog') || await hasPendingFeed('stock');
  Future<void> _setCursor(DatabaseExecutor tx, String feed, int cursor) => tx
      .update('cursors', {'value': cursor}, where: 'feed=?', whereArgs: [feed])
      .then((_) {});
  void _page(int before, int after, List<int> sequences, bool more) {
    if (sequences.length > 50 ||
        after != before + sequences.length ||
        (more && sequences.isEmpty)) {
      throw const FormatException('Invalid delta page');
    }
    for (var i = 0; i < sequences.length; i++) {
      if (sequences[i] != before + i + 1) {
        throw const FormatException('Gapped delta page');
      }
    }
  }

  Future<void> applyCatalog(DeltaPage<CatalogChange> page) =>
      _db.transaction((tx) async {
        _page(await _cursor(tx, 'catalog'), page.cursor,
            page.changes.map((c) => c.sequence).toList(), page.hasMore);
        for (final c in page.changes) {
          final p = c.product;
          if (p.revision < 1) {
            throw const FormatException('Invalid product revision');
          }
          final fields = {
            'id': p.id,
            'sku': p.sku,
            'name': p.name,
            'active': p.active ? 1 : 0,
            'body': jsonEncode(p.toMap()),
            'catalog_sequence': c.sequence
          };
          final existing =
              await tx.query('products', where: 'id=?', whereArgs: [p.id]);
          if (existing.isEmpty) {
            await tx.insert('products', fields);
          } else {
            await tx
                .update('products', fields, where: 'id=?', whereArgs: [p.id]);
          }
          await tx.delete('barcodes', where: 'product=?', whereArgs: [p.id]);
          for (var i = 0; i < p.units.length; i++) {
            if (p.units[i].barcode.isNotEmpty) {
              await tx.insert('barcodes',
                  {'barcode': p.units[i].barcode, 'product': p.id, 'unit': i});
            }
          }
        }
        await _setCursor(tx, 'catalog', page.cursor);
        await tx.update('sync_state', {'has_more': page.hasMore ? 1 : 0},
            where: 'feed=?', whereArgs: ['catalog']);
      });
  Future<void> applyStock(DeltaPage<StockEvent> page) =>
      _db.transaction((tx) async {
        _page(await _cursor(tx, 'stock'), page.cursor,
            page.changes.map((c) => c.sequence).toList(), page.hasMore);
        for (final event in page.changes) {
          var counts = await tx
              .query('ledger', where: 'id=?', whereArgs: [event.operationId]);
          if (event.kind == 'transferOut' || event.kind == 'transferIn') {
            final transfers = await tx.query('transfers');
            for (final row in transfers) {
              final transfer = StockTransferIntent.fromMap(
                  Map<String, Object?>.from(
                      jsonDecode(row['body'] as String) as Map));
              if ((event.kind == 'transferOut' &&
                      event.operationId == transfer.id) ||
                  (event.kind == 'transferIn' &&
                      event.operationId == '${transfer.id}-receive')) {
                counts = [];
                for (final item in transfer.items) {
                  final localId = event.kind == 'transferOut'
                      ? '${transfer.id}-${item.productId}'
                      : '${transfer.id}-in-${item.productId}';
                  counts.addAll(await tx
                      .query('ledger', where: 'id=?', whereArgs: [localId]));
                }
                break;
              }
            }
          }
          final sales = await tx.query('sale_stock',
              where: 'sale=?', whereArgs: [event.operationId]);
          if (counts.isNotEmpty) {
            for (final local in counts) {
              final op = jsonDecode(local['body'] as String) as Map;
              final kind = op['kind'] == 'opening' ? 'count' : op['kind'];
              final positions = event.positions
                  .where((p) => p.productId == op['productId'])
                  .toList();
              if (kind != event.kind ||
                  positions.length != 1 ||
                  (kind == 'count'
                      ? positions.single.quantity != op['quantity']
                      : positions.single.delta != local['delta'])) {
                throw const FormatException(
                    'Stock delta does not match local operation');
              }
              await tx.update(
                  'outbox',
                  {
                    'status': 'accepted',
                    'sequence': event.sequence,
                    'message': null
                  },
                  where: "id=? AND status IN ('pending','accepted')",
                  whereArgs: [local['id']]);
            }
          }
          if (sales.isNotEmpty) {
            final deltas = {for (final s in sales) s['product']: s['delta']};
            if (event.kind != 'sale' ||
                deltas.length != event.positions.length ||
                event.positions.any((p) => deltas[p.productId] != p.delta)) {
              throw const FormatException(
                  'Stock event does not match local receipt');
            }
            final ack = await tx.query('checkout_outbox',
                where: 'id=?', whereArgs: [event.operationId]);
            if (ack.single['status'] == 'accepted' &&
                ack.single['sequence'] != event.sequence) {
              throw const FormatException(
                  'Stock event has another acknowledgement');
            }
            await tx.update(
                'checkout_outbox',
                {
                  'status': 'accepted',
                  'sequence': event.sequence,
                  'message': null
                },
                where: 'id=?',
                whereArgs: [event.operationId]);
          }
          final refunds = await tx.query('refund_stock',
              where: 'refund=?', whereArgs: [event.operationId]);
          if (refunds.isNotEmpty) {
            final deltas = {for (final r in refunds) r['product']: r['delta']};
            if (!['refund', 'void'].contains(event.kind) ||
                deltas.length != event.positions.length ||
                event.positions.any((p) => deltas[p.productId] != p.delta)) {
              throw const FormatException(
                  'Stock event does not match local refund');
            }
            final ack = await tx.query('checkout_outbox',
                where: 'id=?', whereArgs: [event.operationId]);
            if (ack.single['status'] == 'accepted' &&
                ack.single['sequence'] != event.sequence) {
              throw const FormatException(
                  'Stock event has another acknowledgement');
            }
            await tx.update(
                'checkout_outbox',
                {
                  'status': 'accepted',
                  'sequence': event.sequence,
                  'message': null
                },
                where: 'id=?',
                whereArgs: [event.operationId]);
          }
          for (final p in event.positions) {
            await tx.insert(
                'stock',
                {
                  'product': p.productId,
                  'quantity': p.quantity,
                  'revision': p.revision
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await tx.update(
              'outbox',
              {
                'status': 'accepted',
                'sequence': event.sequence,
                'message': null
              },
              where: "id=? AND status IN ('pending','accepted')",
              whereArgs: [event.operationId]);
        }
        await _setCursor(tx, 'stock', page.cursor);
        await tx.update('sync_state', {'has_more': page.hasMore ? 1 : 0},
            where: 'feed=?', whereArgs: ['stock']);
      });
  static CatalogProduct _product(Object? body) => CatalogProduct.fromMap(
      Map<String, Object?>.from(jsonDecode(body as String) as Map));
  Future<List<InventoryRow>> search(String query,
      {bool shortagesOnly = false, bool includeArchived = false}) async {
    final cursor = await stockCursor();
    final escaped = query
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final saleUnsettled =
        "(o.status IN ('pending','conflict','blocked') OR (o.status='accepted' AND o.sequence>$cursor))";
    final rows = await _db.rawQuery("""SELECT p.body,
        COALESCE(lc.quantity,COALESCE(s.quantity,0)) + COALESCE((SELECT SUM(ss.delta) FROM sale_stock ss JOIN checkout_outbox o ON o.id=ss.sale JOIN local_order so ON so.id=ss.sale WHERE ss.product=p.id AND ((co.ordinal IS NOT NULL AND so.ordinal>co.ordinal) OR (co.ordinal IS NULL AND $saleUnsettled))),0) + COALESCE((SELECT SUM(rs.delta) FROM refund_stock rs JOIN checkout_outbox o ON o.id=rs.refund JOIN local_order so ON so.id=rs.refund WHERE rs.product=p.id AND ((co.ordinal IS NOT NULL AND so.ordinal>co.ordinal) OR (co.ordinal IS NULL AND $saleUnsettled))),0) + COALESCE((SELECT SUM(l.delta) FROM ledger l JOIN outbox o ON o.id=l.id JOIN local_order lo ON lo.id=l.id WHERE l.product=p.id AND json_extract(l.body,'\$.projectionVersion')=2 AND ((co.ordinal IS NOT NULL AND lo.ordinal>co.ordinal) OR (co.ordinal IS NULL AND $saleUnsettled))),0) AS local_quantity,
        COALESCE(s.revision,0) AS revision,
        (SELECT COUNT(*) FROM ledger l JOIN outbox o ON o.id=l.id WHERE l.product=p.id AND $saleUnsettled)+(SELECT COUNT(*) FROM sale_stock ss JOIN checkout_outbox o ON o.id=ss.sale WHERE ss.product=p.id AND $saleUnsettled)+(SELECT COUNT(*) FROM refund_stock rs JOIN checkout_outbox o ON o.id=rs.refund WHERE rs.product=p.id AND $saleUnsettled) AS unsettled
        FROM products p LEFT JOIN stock s ON s.product=p.id
        LEFT JOIN ledger lc ON lc.id=(SELECT l.id FROM ledger l JOIN outbox o ON o.id=l.id JOIN local_order lo ON lo.id=l.id WHERE l.product=p.id AND COALESCE(json_extract(l.body,'\$.projectionVersion'),1)<>2 AND $saleUnsettled ORDER BY lo.ordinal DESC LIMIT 1)
        LEFT JOIN local_order co ON co.id=lc.id
        WHERE p.active=${includeArchived ? 0 : 1} AND (p.name LIKE ? ESCAPE '\\' OR p.sku LIKE ? ESCAPE '\\' OR p.id IN (SELECT product FROM barcodes WHERE barcode=?))
        ${shortagesOnly ? 'AND local_quantity<0' : ''} ORDER BY p.name COLLATE NOCASE,p.id LIMIT 50""",
        ['%$escaped%', '%$escaped%', query.trim()]);
    return rows
        .map((r) => InventoryRow(
            _product(r['body']),
            r['local_quantity'] as int,
            r['revision'] as int,
            r['unsettled'] as int))
        .toList();
  }

  Future<BarcodeMatch?> lookupBarcode(String barcode) async {
    final rows = await _db.rawQuery(
        'SELECT p.body,b.unit FROM barcodes b JOIN products p ON p.id=b.product WHERE b.barcode=? AND p.active=1',
        [barcode]);
    if (rows.isEmpty) return null;
    final p = _product(rows.single['body']);
    return BarcodeMatch(p, p.units[rows.single['unit'] as int]);
  }

  Future<InventoryRow?> getProduct(String id) async {
    final cursor = await stockCursor();
    final saleUnsettled =
        "(o.status IN ('pending','conflict','blocked') OR (o.status='accepted' AND o.sequence>$cursor))";
    final rows = await _db.rawQuery("""SELECT p.body,
        COALESCE(lc.quantity,COALESCE(s.quantity,0)) + COALESCE((SELECT SUM(ss.delta) FROM sale_stock ss JOIN checkout_outbox o ON o.id=ss.sale JOIN local_order so ON so.id=ss.sale WHERE ss.product=p.id AND ((co.ordinal IS NOT NULL AND so.ordinal>co.ordinal) OR (co.ordinal IS NULL AND $saleUnsettled))),0) + COALESCE((SELECT SUM(rs.delta) FROM refund_stock rs JOIN checkout_outbox o ON o.id=rs.refund JOIN local_order so ON so.id=rs.refund WHERE rs.product=p.id AND ((co.ordinal IS NOT NULL AND so.ordinal>co.ordinal) OR (co.ordinal IS NULL AND $saleUnsettled))),0) + COALESCE((SELECT SUM(l.delta) FROM ledger l JOIN outbox o ON o.id=l.id JOIN local_order lo ON lo.id=l.id WHERE l.product=p.id AND json_extract(l.body,'\$.projectionVersion')=2 AND ((co.ordinal IS NOT NULL AND lo.ordinal>co.ordinal) OR (co.ordinal IS NULL AND $saleUnsettled))),0) AS local_quantity,
        COALESCE(s.revision,0) AS revision,
        (SELECT COUNT(*) FROM ledger l JOIN outbox o ON o.id=l.id WHERE l.product=p.id AND $saleUnsettled)+(SELECT COUNT(*) FROM sale_stock ss JOIN checkout_outbox o ON o.id=ss.sale WHERE ss.product=p.id AND $saleUnsettled)+(SELECT COUNT(*) FROM refund_stock rs JOIN checkout_outbox o ON o.id=rs.refund WHERE rs.product=p.id AND $saleUnsettled) AS unsettled
        FROM products p LEFT JOIN stock s ON s.product=p.id
        LEFT JOIN ledger lc ON lc.id=(SELECT l.id FROM ledger l JOIN outbox o ON o.id=l.id JOIN local_order lo ON lo.id=l.id WHERE l.product=p.id AND COALESCE(json_extract(l.body,'\$.projectionVersion'),1)<>2 AND $saleUnsettled ORDER BY lo.ordinal DESC LIMIT 1)
        LEFT JOIN local_order co ON co.id=lc.id
        WHERE p.id=? LIMIT 1""", [id]);
    if (rows.isEmpty) return null;
    final r = rows.single;
    return InventoryRow(_product(r['body']), r['local_quantity'] as int,
        r['revision'] as int, r['unsettled'] as int);
  }

  Future<void> recordReceiving({
    required String operationId,
    required String productId,
    required int quantity,
    required String reason,
    String? batchNumber,
    String? expiryDate,
  }) =>
      _db.transaction((tx) async {
        if (operationId.isEmpty ||
            operationId.length > 128 ||
            operationId.contains('/') ||
            quantity <= 0 ||
            quantity > 1000000000 ||
            reason.trim().isEmpty ||
            reason.length > 160) {
          throw ArgumentError('Invalid receiving operation');
        }
        final productRows = await tx.query('products',
            where: 'id=? AND active=1', whereArgs: [productId]);
        if (productRows.isEmpty) throw StateError('Product unavailable');

        final stockRows =
            await tx.query('stock', where: 'product=?', whereArgs: [productId]);
        final base =
            stockRows.isEmpty ? 0 : stockRows.single['quantity'] as int;
        final revision =
            stockRows.isEmpty ? 0 : stockRows.single['revision'] as int;
        final newQuantity = base + quantity;

        final op = StockOperation(
          id: operationId,
          productId: productId,
          kind: 'receiving',
          quantity: newQuantity,
          expectedRevision: revision,
          details: const {'projectionVersion': 2},
          reason: reason.trim(),
        );

        await tx.insert('ledger', {
          'id': operationId,
          'product': productId,
          'delta': quantity,
          'quantity': newQuantity,
          'body': jsonEncode(op.toMap()),
        });
        await tx
            .insert('local_order', {'id': operationId, 'kind': 'receiving'});
        await tx.insert('outbox', {'id': operationId, 'status': 'pending'});

        if (batchNumber != null &&
            batchNumber.isNotEmpty &&
            expiryDate != null &&
            expiryDate.isNotEmpty) {
          final batchId = '$operationId-$batchNumber';
          await tx.insert('batches', {
            'id': batchId,
            'product': productId,
            'batch_number': batchNumber,
            'expiry_date': expiryDate,
            'quantity': quantity,
          });
        }
      });

  Future<List<BatchExpiryRecord>> getBatches(String productId) async {
    final rows = await _db.query('batches',
        where: 'product=? AND quantity > 0',
        whereArgs: [productId],
        orderBy: 'expiry_date ASC');
    return rows
        .map((r) => BatchExpiryRecord(
              productId: r['product'] as String,
              batchNumber: r['batch_number'] as String,
              expiryDate: r['expiry_date'] as String,
              quantity: r['quantity'] as int,
            ))
        .toList();
  }

  Future<void> recordStockAdjustment({
    required String operationId,
    required String productId,
    required int delta,
    required String reason,
  }) =>
      _db.transaction((tx) async {
        if (operationId.isEmpty ||
            operationId.length > 128 ||
            operationId.contains('/') ||
            delta == 0 ||
            delta.abs() > 1000000000 ||
            reason.trim().isEmpty ||
            reason.length > 160) {
          throw ArgumentError('Invalid adjustment operation');
        }
        final productRows = await tx.query('products',
            where: 'id=? AND active=1', whereArgs: [productId]);
        if (productRows.isEmpty) throw StateError('Product unavailable');

        final stockRows =
            await tx.query('stock', where: 'product=?', whereArgs: [productId]);
        final base =
            stockRows.isEmpty ? 0 : stockRows.single['quantity'] as int;
        final revision =
            stockRows.isEmpty ? 0 : stockRows.single['revision'] as int;
        final cursor = await _cursor(tx, 'stock');
        final pendingMovements = await tx.rawQuery(
            "SELECT COUNT(*) AS n FROM ledger l JOIN outbox o ON o.id=l.id WHERE l.product=? AND (o.status='pending' OR (o.status='accepted' AND o.sequence>?))",
            [productId, cursor]);
        final expectedRevision =
            revision + (pendingMovements.single['n'] as int);
        final newQuantity = base + delta;

        final op = StockOperation(
          id: operationId,
          productId: productId,
          kind: 'adjustment',
          quantity: newQuantity,
          expectedRevision: expectedRevision,
          details: const {'projectionVersion': 2},
          reason: reason.trim(),
        );

        await tx.insert('ledger', {
          'id': operationId,
          'product': productId,
          'delta': delta,
          'quantity': newQuantity,
          'body': jsonEncode(op.toMap()),
        });
        await tx
            .insert('local_order', {'id': operationId, 'kind': 'adjustment'});
        await tx.insert('outbox', {'id': operationId, 'status': 'pending'});
      });

  Future<void> dispatchTransfer({
    required String transferId,
    required String destinationBranchId,
    required List<StockTransferItem> items,
    required DateTime occurredAt,
    String notes = '',
  }) =>
      _db.transaction((tx) async {
        if (items.length > 20) {
          throw ArgumentError('Select at most twenty transfer products');
        }
        final intent = StockTransferIntent(
          id: transferId,
          sourceBranchId: branchId,
          destinationBranchId: destinationBranchId,
          items: items,
          occurredAt: occurredAt,
          status: StockTransferStatus.dispatched,
          notes: notes,
        );

        for (final item in items) {
          final stockRows = await tx
              .query('stock', where: 'product=?', whereArgs: [item.productId]);
          final base =
              stockRows.isEmpty ? 0 : stockRows.single['quantity'] as int;
          final revision =
              stockRows.isEmpty ? 0 : stockRows.single['revision'] as int;
          final newQuantity = base - item.quantity;

          final opId = '$transferId-${item.productId}';
          final op = StockOperation(
            id: opId,
            productId: item.productId,
            kind: 'transferOut',
            quantity: newQuantity,
            expectedRevision: revision,
            details: const {'projectionVersion': 2},
            reason: 'Transfer to $destinationBranchId',
          );

          await tx.insert('ledger', {
            'id': opId,
            'product': item.productId,
            'delta': -item.quantity,
            'quantity': newQuantity,
            'body': jsonEncode(op.toMap()),
          });
          await tx.insert('local_order', {'id': opId, 'kind': 'transferOut'});
          await tx.insert('outbox', {'id': opId, 'status': 'pending'});
        }

        await tx.insert('transfers', {
          'id': transferId,
          'source_branch': branchId,
          'destination_branch': destinationBranchId,
          'status': StockTransferStatus.dispatched.name,
          'body': jsonEncode(intent.toMap()),
          'occurred_at': occurredAt.toIso8601String(),
        });
      });

  Future<StockTransferIntent?> getTransfer(String transferId) async {
    final rows =
        await _db.query('transfers', where: 'id=?', whereArgs: [transferId]);
    if (rows.isEmpty) return null;
    final map =
        jsonDecode(rows.single['body'] as String) as Map<String, Object?>;
    return StockTransferIntent.fromMap(map);
  }

  Future<void> receiveTransfer({
    required String transferId,
    required DateTime receivedAt,
  }) =>
      _db.transaction((tx) async {
        final rows =
            await tx.query('transfers', where: 'id=?', whereArgs: [transferId]);
        if (rows.isEmpty) {
          throw StateError('Transfer not found');
        }
        final transfer = StockTransferIntent.fromMap(
            jsonDecode(rows.single['body'] as String) as Map<String, Object?>);
        if (transfer.destinationBranchId != branchId) {
          throw StateError('Transfer destination does not match this branch');
        }
        if (transfer.status == StockTransferStatus.received) {
          throw StateError('Transfer is already received');
        }
        if (transfer.status != StockTransferStatus.dispatched ||
            transfer.items.length > 20) {
          throw StateError('Transfer manifest needs review');
        }

        for (final item in transfer.items) {
          final stockRows = await tx
              .query('stock', where: 'product=?', whereArgs: [item.productId]);
          final base =
              stockRows.isEmpty ? 0 : stockRows.single['quantity'] as int;
          final revision =
              stockRows.isEmpty ? 0 : stockRows.single['revision'] as int;
          final newQuantity = base + item.quantity;

          final opId = '$transferId-in-${item.productId}';
          final op = StockOperation(
            id: opId,
            productId: item.productId,
            kind: 'transferIn',
            quantity: newQuantity,
            expectedRevision: revision,
            details: const {'projectionVersion': 2},
            reason: 'Received from ${transfer.sourceBranchId}',
          );

          await tx.insert('ledger', {
            'id': opId,
            'product': item.productId,
            'delta': item.quantity,
            'quantity': newQuantity,
            'body': jsonEncode(op.toMap()),
          });
          await tx.insert('local_order', {'id': opId, 'kind': 'transferIn'});
          await tx.insert('outbox', {'id': opId, 'status': 'pending'});
        }

        final updatedTransfer = transfer.copyWith(
          status: StockTransferStatus.received,
        );

        await tx.update(
          'transfers',
          {
            'status': StockTransferStatus.received.name,
            'body': jsonEncode(updatedTransfer.toMap()),
          },
          where: 'id=?',
          whereArgs: [transferId],
        );
      });

  Future<void> cacheIncomingTransfers(List<StockTransferIntent> transfers) =>
      _db.transaction((tx) async {
        for (final transfer in transfers) {
          if (transfer.destinationBranchId != branchId ||
              transfer.status != StockTransferStatus.dispatched ||
              transfer.items.length > 20) {
            throw ArgumentError('Incoming transfer does not match this branch');
          }
          final existing = await tx
              .query('transfers', where: 'id=?', whereArgs: [transfer.id]);
          if (existing.isNotEmpty) {
            final saved = StockTransferIntent.fromMap(Map<String, Object?>.from(
                jsonDecode(existing.single['body'] as String) as Map));
            if (saved.sourceBranchId != transfer.sourceBranchId ||
                saved.destinationBranchId != transfer.destinationBranchId ||
                jsonEncode(saved.items.map((i) => i.toMap()).toList()) !=
                    jsonEncode(transfer.items.map((i) => i.toMap()).toList())) {
              throw StateError('Incoming transfer changed; review required');
            }
            // Preserve the immutable local receipt and its pending stock projection.
            continue;
          }
          await tx.insert('transfers', {
            'id': transfer.id,
            'source_branch': transfer.sourceBranchId,
            'destination_branch': transfer.destinationBranchId,
            'status': transfer.status.name,
            'body': jsonEncode(transfer.toMap()),
            'occurred_at': transfer.occurredAt.toIso8601String(),
          });
        }
      });

  Future<List<StockTransferIntent>> listTransfers() async {
    final rows = await _db.query('transfers', orderBy: 'occurred_at DESC');
    return rows
        .map((r) => StockTransferIntent.fromMap(
            jsonDecode(r['body'] as String) as Map<String, Object?>))
        .toList();
  }

  Future<void> recordCount(
          {required String id,
          required String productId,
          required int quantity,
          required String kind,
          required String reason}) =>
      _db.transaction((tx) async {
        if (id.isEmpty ||
            id.length > 128 ||
            id.contains('/') ||
            quantity < 0 ||
            quantity > 1000000000 ||
            !['opening', 'count'].contains(kind) ||
            reason.trim().isEmpty ||
            reason.length > 160) {
          throw ArgumentError('Invalid count');
        }
        final product = await tx.query('products',
            where: 'id=? AND active=1', whereArgs: [productId]);
        if (product.isEmpty) throw StateError('Product unavailable');
        final unsettled = await tx.rawQuery(
            "SELECT COUNT(*) AS n FROM ledger l JOIN outbox o ON o.id=l.id WHERE l.product=? AND (o.status IN ('pending','conflict','blocked') OR (o.status='accepted' AND o.sequence>?))",
            [productId, await _cursor(tx, 'stock')]);
        if (unsettled.single['n'] != 0) {
          throw StateError('Resolve previous count first');
        }
        final sales = await tx.rawQuery(
            "SELECT COUNT(*) AS n FROM sale_stock ss JOIN checkout_outbox o ON o.id=ss.sale WHERE ss.product=? AND (o.status IN ('pending','conflict','blocked') OR (o.status='accepted' AND o.sequence>?))",
            [productId, await _cursor(tx, 'stock')]);
        if (sales.single['n'] != 0) {
          throw StateError('Sync sales before recording a count');
        }
        final stock =
            await tx.query('stock', where: 'product=?', whereArgs: [productId]);
        final revision = stock.isEmpty ? 0 : stock.single['revision'] as int;
        final base = stock.isEmpty ? 0 : stock.single['quantity'] as int;
        if (kind == 'opening' && revision != 0) {
          throw StateError('Opening already recorded');
        }
        final op = StockOperation(
            id: id,
            productId: productId,
            kind: kind,
            quantity: quantity,
            expectedRevision: revision,
            reason: reason.trim());
        await tx.insert('ledger', {
          'id': id,
          'product': productId,
          'delta': quantity - base,
          'quantity': quantity,
          'body': jsonEncode(op.toMap())
        });
        await tx.insert('local_order', {'id': id, 'kind': 'count'});
        await tx.insert('outbox', {'id': id, 'status': 'pending'});
      });
  Future<List<StockOperation>> operations(
      {bool pendingOnly = false, bool unsettledOnly = false}) async {
    final rows = await _db.rawQuery(
        "SELECT l.body,l.delta,p.name AS product_name,o.status,o.message FROM ledger l JOIN outbox o ON o.id=l.id LEFT JOIN products p ON p.id=l.product ${pendingOnly ? "WHERE o.status='pending'" : unsettledOnly ? "WHERE o.status IN ('pending','conflict','blocked')" : ''} ORDER BY l.rowid LIMIT ${pendingOnly ? 20 : 50}");
    final result = <StockOperation>[];
    for (final r in rows) {
      final m = jsonDecode(r['body'] as String) as Map;
      final details = <String, Object?>{
        if (m['projectionVersion'] != null)
          'projectionVersion': m['projectionVersion']
      };
      if (['receiving', 'adjustment'].contains(m['kind'])) {
        details['delta'] = r['delta'];
        if (m['kind'] == 'receiving') {
          final batches = await _db.query('batches',
              where: 'substr(id,1,?)=?',
              whereArgs: [
                '${m['operationId']}-'.length,
                '${m['operationId']}-'
              ]);
          if (batches.length == 1) {
            details['batchNumber'] = batches.single['batch_number'];
            details['expiryDate'] = batches.single['expiry_date'];
          }
        }
      }
      if (['transferOut', 'transferIn'].contains(m['kind'])) {
        for (final transfer in await listTransfers()) {
          final expectedId = m['kind'] == 'transferOut'
              ? '${transfer.id}-${m['productId']}'
              : '${transfer.id}-in-${m['productId']}';
          if (m['operationId'] != expectedId) continue;
          details.addAll({
            'transferId': transfer.id,
            'sourceBranchId': transfer.sourceBranchId,
            'destinationBranchId': transfer.destinationBranchId,
            'items': transfer.items.map((i) => i.toMap()).toList(),
            'operationId': '${transfer.id}-receive',
            'eventOperationId': m['kind'] == 'transferOut'
                ? transfer.id
                : '${transfer.id}-receive',
          });
          break;
        }
      }
      result.add(StockOperation(
          id: m['operationId'] as String,
          productId: m['productId'] as String,
          kind: m['kind'] as String,
          quantity: m['quantity'] as int,
          expectedRevision: m['expectedRevision'] as int,
          reason: m['reason'] as String,
          productName: r['product_name'] as String? ?? '',
          status: r['status'] as String,
          details: details,
          message: r['message'] as String?));
    }
    return result;
  }

  Future<List<StockOperation>> pending() => operations(pendingOnly: true);
  Future<int> unsettledCount() async => (await _db.rawQuery(
          "SELECT COUNT(*) AS n FROM outbox WHERE status IN ('pending','conflict','blocked')"))
      .single['n'] as int;
  Future<int> ledgerCount() async =>
      (await _db.rawQuery('SELECT COUNT(*) AS n FROM ledger')).single['n']
          as int;
  Future<void> acknowledge(String id, StockAck ack) =>
      _db.transaction((tx) async {
        if (ack.operationId != id ||
            !['accepted', 'duplicate', 'conflict', 'blocked']
                .contains(ack.status) ||
            (['accepted', 'duplicate'].contains(ack.status) &&
                (ack.sequence == null || ack.sequence! < 1))) {
          throw const FormatException('Invalid stock acknowledgement');
        }
        final rows = await tx.query('outbox', where: 'id=?', whereArgs: [id]);
        if (rows.isEmpty) {
          throw const FormatException('Unknown acknowledgement');
        }
        if (rows.single['status'] == 'accepted' ||
            rows.single['status'] == 'withdrawn') {
          return;
        }
        if (['accepted', 'duplicate'].contains(ack.status)) {
          final cursor = await _cursor(tx, 'stock');
          final settledSequence = rows.single['sequence'] as int?;
          if (ack.sequence! <= cursor && settledSequence == null) {
            throw const FormatException(
                'Acknowledgement sequence is already behind the local feed');
          }
        }
        await tx.update(
            'outbox',
            {
              'status': ack.status == 'duplicate' ? 'accepted' : ack.status,
              'sequence': ack.sequence,
              'message': ack.message
            },
            where: 'id=?',
            whereArgs: [id]);
      });
  Future<void> withdraw(String id, String compensationId) =>
      _db.transaction((tx) async {
        final rows = await tx.rawQuery(
            'SELECT l.*,o.status FROM ledger l JOIN outbox o ON o.id=l.id WHERE l.id=?',
            [id]);
        if (rows.isEmpty ||
            !['conflict', 'blocked'].contains(rows.single['status'])) {
          throw StateError('Only rejected counts can be withdrawn');
        }
        final row = rows.single;
        await tx.insert('ledger', {
          'id': compensationId,
          'product': row['product'],
          'delta': -(row['delta'] as int),
          'body':
              jsonEncode({'kind': 'withdrawal', 'operationId': compensationId}),
          'reverses': id
        });
        await tx.update('outbox', {'status': 'withdrawn'},
            where: 'id=?', whereArgs: [id]);
      });

  // ==========================================
  // Phase 6: Procurement, Suppliers & POs
  // ==========================================

  Future<void> saveSupplier(Supplier supplier) async {
    await _db.insert(
      'suppliers',
      {
        'id': supplier.id,
        'name': supplier.name,
        'contact_person': supplier.contactPerson,
        'phone': supplier.phone,
        'email': supplier.email,
        'address': supplier.address,
        'lead_time_days': supplier.leadTimeDays,
        'active': supplier.active ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Supplier>> listSuppliers({bool activeOnly = true}) async {
    final rows = await _db.query(
      'suppliers',
      where: activeOnly ? 'active=1' : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => Supplier(
              id: r['id'] as String,
              name: r['name'] as String,
              contactPerson: r['contact_person'] as String,
              phone: r['phone'] as String,
              email: r['email'] as String,
              address: r['address'] as String,
              leadTimeDays: r['lead_time_days'] as int,
              active: (r['active'] as int) == 1,
            ))
        .toList();
  }

  Future<void> savePurchaseOrder(PurchaseOrder po) async {
    await _db.insert(
      'purchase_orders',
      {
        'id': po.id,
        'supplier_id': po.supplierId,
        'supplier_name': po.supplierName,
        'warehouse_id': po.warehouseId,
        'status': po.status.name,
        'body': jsonEncode(po.toMap()),
        'created_at': po.createdAt.toIso8601String(),
        'expected_delivery_date': po.expectedDeliveryDate?.toIso8601String(),
        'notes': po.notes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PurchaseOrder>> listPurchaseOrders(
      {PurchaseOrderStatus? status}) async {
    final rows = await _db.query(
      'purchase_orders',
      where: status != null ? 'status=?' : null,
      whereArgs: status != null ? [status.name] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) {
      final body = jsonDecode(r['body'] as String) as Map<String, dynamic>;
      return PurchaseOrder.fromMap(body);
    }).toList();
  }

  Future<void> recordSupplierReceiving({
    required String poId,
    required String productId,
    required int quantityReceived,
    String? batchNumber,
    String? expiryDate,
  }) =>
      _db.transaction((tx) async {
        final batch = batchNumber?.trim() ?? '';
        final expiry = expiryDate?.trim() ?? '';
        final parsedExpiry = DateTime.tryParse(expiry);
        if (batch.length > 80 ||
            (batch.isEmpty != expiry.isEmpty) ||
            (expiry.isNotEmpty &&
                (expiry.length != 10 ||
                    parsedExpiry == null ||
                    parsedExpiry.toIso8601String().substring(0, 10) !=
                        expiry))) {
          throw ArgumentError('Provide a batch and valid expiry date together');
        }
        if (quantityReceived <= 0) {
          throw ArgumentError('Received quantity must be positive');
        }
        final rows =
            await tx.query('purchase_orders', where: 'id=?', whereArgs: [poId]);
        if (rows.isEmpty) throw StateError('Purchase order not found');

        final body =
            jsonDecode(rows.single['body'] as String) as Map<String, dynamic>;
        final po = PurchaseOrder.fromMap(body);
        final ordered =
            po.lines.where((line) => line.productId == productId).toList();
        if (ordered.length != 1 ||
            ordered.single.quantityReceived + quantityReceived >
                ordered.single.quantity ||
            ![
              PurchaseOrderStatus.submitted,
              PurchaseOrderStatus.partiallyReceived
            ].contains(po.status)) {
          throw StateError('Receiving exceeds the open purchase order');
        }
        final operationId = sha256
            .convert(utf8.encode(
                '$poId:$productId:${ordered.single.quantityReceived}:$quantityReceived'))
            .toString();
        await _queueProcurement(tx, 'managePurchaseOrders', {
          'action': 'receive',
          'poId': poId,
          'productId': productId,
          'quantityReceived': quantityReceived,
          'operationId': operationId,
          if (batch.isNotEmpty) 'batchNumber': batch,
          if (expiry.isNotEmpty) 'expiryDate': expiry
        });

        final updatedLines = po.lines.map((l) {
          if (l.productId == productId) {
            return l.copyWith(
                quantityReceived: l.quantityReceived + quantityReceived);
          }
          return l;
        }).toList();

        final allFullyReceived = updatedLines.every((l) => l.isFullyReceived);
        final anyReceived = updatedLines.any((l) => l.quantityReceived > 0);
        final newStatus = allFullyReceived
            ? PurchaseOrderStatus.completed
            : (anyReceived ? PurchaseOrderStatus.partiallyReceived : po.status);

        final updatedPo = po.copyWith(lines: updatedLines, status: newStatus);

        await tx.update(
          'purchase_orders',
          {
            'status': updatedPo.status.name,
            'body': jsonEncode(updatedPo.toMap()),
          },
          where: 'id=?',
          whereArgs: [poId],
        );

        // Update warehouse stock
        final whStockRows = await tx.query(
          'warehouse_stock',
          where: 'warehouse_id=? AND product_id=?',
          whereArgs: [po.warehouseId, productId],
        );
        if (whStockRows.isEmpty) {
          await tx.insert('warehouse_stock', {
            'warehouse_id': po.warehouseId,
            'product_id': productId,
            'physical_quantity': quantityReceived,
            'reserved_quantity': 0,
          });
        } else {
          final currentPhys = whStockRows.single['physical_quantity'] as int;
          await tx.update(
            'warehouse_stock',
            {'physical_quantity': currentPhys + quantityReceived},
            where: 'warehouse_id=? AND product_id=?',
            whereArgs: [po.warehouseId, productId],
          );
        }

        // Also record batch if provided
        if (batchNumber != null &&
            batchNumber.isNotEmpty &&
            expiryDate != null &&
            expiryDate.isNotEmpty) {
          await tx.insert(
            'batches',
            {
              'id': 'wh-$operationId',
              'product': productId,
              'batch_number': batch,
              'expiry_date': expiry,
              'quantity': quantityReceived,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

  // ==========================================
  // Phase 6: Warehouses & Stock Reservation
  // ==========================================

  Future<void> saveWarehouse(Warehouse wh) async {
    await _db.insert(
      'warehouses',
      {
        'id': wh.id,
        'name': wh.name,
        'code': wh.code,
        'address': wh.address,
        'active': wh.active ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Warehouse>> listWarehouses({bool activeOnly = true}) async {
    final rows = await _db.query(
      'warehouses',
      where: activeOnly ? 'active=1' : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => Warehouse(
              id: r['id'] as String,
              name: r['name'] as String,
              code: r['code'] as String,
              address: r['address'] as String,
              active: (r['active'] as int) == 1,
            ))
        .toList();
  }

  Future<WarehouseStock?> getWarehouseStock({
    required String warehouseId,
    required String productId,
  }) async {
    final rows = await _db.query(
      'warehouse_stock',
      where: 'warehouse_id=? AND product_id=?',
      whereArgs: [warehouseId, productId],
    );
    if (rows.isEmpty) return null;
    return WarehouseStock(
      warehouseId: rows.single['warehouse_id'] as String,
      productId: rows.single['product_id'] as String,
      physicalQuantity: rows.single['physical_quantity'] as int,
      reservedQuantity: rows.single['reserved_quantity'] as int,
    );
  }

  Future<List<WarehouseStock>> listWarehouseStock(String warehouseId) async {
    final rows = await _db.query(
      'warehouse_stock',
      where: 'warehouse_id=?',
      whereArgs: [warehouseId],
    );
    return rows
        .map((r) => WarehouseStock(
              warehouseId: r['warehouse_id'] as String,
              productId: r['product_id'] as String,
              physicalQuantity: r['physical_quantity'] as int,
              reservedQuantity: r['reserved_quantity'] as int,
            ))
        .toList();
  }

  Future<void> adjustWarehouseStock({
    required String warehouseId,
    required String productId,
    required int physicalDelta,
    String reason = 'Warehouse stock correction',
  }) =>
      _db.transaction((tx) async {
        final rows = await tx.query(
          'warehouse_stock',
          where: 'warehouse_id=? AND product_id=?',
          whereArgs: [warehouseId, productId],
        );
        if (physicalDelta == 0 ||
            physicalDelta.abs() > 1000000000 ||
            reason.trim().isEmpty) {
          throw ArgumentError('Invalid stock adjustment');
        }
        final current =
            rows.isEmpty ? 0 : rows.single['physical_quantity'] as int;
        final reserved =
            rows.isEmpty ? 0 : rows.single['reserved_quantity'] as int;
        if (current + physicalDelta < reserved) {
          throw StateError('Adjustment would consume reserved stock');
        }
        final operationId = sha256
            .convert(utf8.encode(
                '$warehouseId:$productId:$current:$physicalDelta:$reason'))
            .toString();
        await _queueProcurement(tx, 'manageWarehouses', {
          'action': 'adjust',
          'warehouseId': warehouseId,
          'productId': productId,
          'delta': physicalDelta,
          'reason': reason.trim(),
          'operationId': operationId
        });
        if (rows.isEmpty) {
          if (physicalDelta < 0) {
            throw StateError('Cannot decrease non-existent stock');
          }
          await tx.insert('warehouse_stock', {
            'warehouse_id': warehouseId,
            'product_id': productId,
            'physical_quantity': physicalDelta,
            'reserved_quantity': 0,
          });
        } else {
          final currentPhys = rows.single['physical_quantity'] as int;
          final newPhys = currentPhys + physicalDelta;
          if (newPhys < 0) throw StateError('Insufficient warehouse stock');
          await tx.update(
            'warehouse_stock',
            {'physical_quantity': newPhys},
            where: 'warehouse_id=? AND product_id=?',
            whereArgs: [warehouseId, productId],
          );
        }
      });

  // ==========================================
  // Phase 6: Restocking Proposals & Owner Approval
  // ==========================================

  Future<void> submitRestockProposal(RestockProposal proposal) =>
      _db.transaction((tx) async {
        await _queueProcurement(tx, 'manageRestockProposals',
            {'action': 'submit', 'proposal': proposal.toMap()});
        await tx.insert(
          'restock_proposals',
          {
            'id': proposal.id,
            'branch_id': proposal.branchId,
            'warehouse_id': proposal.warehouseId,
            'status': proposal.status.name,
            'body': jsonEncode(proposal.toMap()),
            'requested_at': proposal.requestedAt.toIso8601String(),
            'reviewed_at': proposal.reviewedAt?.toIso8601String(),
            'reviewed_by': proposal.reviewedBy,
            'rejection_reason': proposal.rejectionReason,
            'notes': proposal.notes,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

  Future<List<RestockProposal>> listRestockProposals({
    String? branchId,
    RestockProposalStatus? status,
  }) async {
    final whereClauses = <String>[];
    final args = <Object?>[];
    if (branchId != null) {
      whereClauses.add('branch_id=?');
      args.add(branchId);
    }
    if (status != null) {
      whereClauses.add('status=?');
      args.add(status.name);
    }

    final rows = await _db.query(
      'restock_proposals',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'requested_at DESC',
    );
    return rows.map((r) {
      final body = jsonDecode(r['body'] as String) as Map<String, dynamic>;
      return RestockProposal.fromMap(body);
    }).toList();
  }

  Future<void> reviewRestockProposal({
    required String proposalId,
    required bool approved,
    required String reviewedBy,
    List<RestockProposalLine>? adjustedLines,
    String? rejectionReason,
  }) =>
      _db.transaction((tx) async {
        final rows = await tx
            .query('restock_proposals', where: 'id=?', whereArgs: [proposalId]);
        if (rows.isEmpty) throw StateError('Restock proposal not found');

        final body =
            jsonDecode(rows.single['body'] as String) as Map<String, dynamic>;
        final proposal = RestockProposal.fromMap(body);

        if (proposal.status != RestockProposalStatus.pendingApproval &&
            proposal.status != RestockProposalStatus.draft) {
          throw StateError('Proposal is not pending approval');
        }

        await _queueProcurement(tx, 'manageRestockProposals', {
          'action': 'review',
          'proposalId': proposalId,
          'approved': approved,
          'adjustedLines': adjustedLines?.map((line) => line.toMap()).toList(),
          'rejectionReason': rejectionReason
        });
        final now = DateTime.now();

        if (!approved) {
          final updated = proposal.copyWith(
            status: RestockProposalStatus.rejected,
            reviewedAt: now,
            reviewedBy: reviewedBy,
            rejectionReason: rejectionReason ?? 'Rejected by owner',
          );
          await tx.update(
            'restock_proposals',
            {
              'status': updated.status.name,
              'reviewed_at': now.toIso8601String(),
              'reviewed_by': reviewedBy,
              'rejection_reason': updated.rejectionReason,
              'body': jsonEncode(updated.toMap()),
            },
            where: 'id=?',
            whereArgs: [proposalId],
          );
          return;
        }

        // If approved: update approved quantities and reserve warehouse stock
        final effectiveLines = (adjustedLines ?? proposal.lines).map((l) {
          final approvedQty =
              adjustedLines == null ? l.suggestedQuantity : l.approvedQuantity;
          return l.copyWith(approvedQuantity: approvedQty);
        }).toList();

        // Check availability and reserve warehouse stock
        for (final line in effectiveLines) {
          final stockRows = await tx.query(
            'warehouse_stock',
            where: 'warehouse_id=? AND product_id=?',
            whereArgs: [proposal.warehouseId, line.productId],
          );
          if (stockRows.isNotEmpty) {
            final res = stockRows.single['reserved_quantity'] as int;
            await tx.update(
              'warehouse_stock',
              {'reserved_quantity': res + line.approvedQuantity},
              where: 'warehouse_id=? AND product_id=?',
              whereArgs: [proposal.warehouseId, line.productId],
            );
          } else {
            await tx.insert('warehouse_stock', {
              'warehouse_id': proposal.warehouseId,
              'product_id': line.productId,
              'physical_quantity': 0,
              'reserved_quantity': line.approvedQuantity,
            });
          }
        }

        final updated = proposal.copyWith(
          status: RestockProposalStatus.approved,
          lines: effectiveLines,
          reviewedAt: now,
          reviewedBy: reviewedBy,
        );

        await tx.update(
          'restock_proposals',
          {
            'status': updated.status.name,
            'reviewed_at': now.toIso8601String(),
            'reviewed_by': reviewedBy,
            'body': jsonEncode(updated.toMap()),
          },
          where: 'id=?',
          whereArgs: [proposalId],
        );
      });

  // ==========================================
  // Phase 6: Fulfillment (Pick & Pack)
  // ==========================================

  Future<void> startPicking({
    required String proposalId,
    required String pickerId,
  }) =>
      _db.transaction((tx) async {
        final rows = await tx
            .query('restock_proposals', where: 'id=?', whereArgs: [proposalId]);
        if (rows.isEmpty) throw StateError('Restock order not found');

        final body =
            jsonDecode(rows.single['body'] as String) as Map<String, dynamic>;
        final proposal = RestockProposal.fromMap(body);
        if (proposal.status != RestockProposalStatus.approved) {
          throw StateError('Order must be approved before picking');
        }

        await _queueProcurement(tx, 'manageRestockProposals', {
          'action': 'fulfill',
          'stage': 'startPick',
          'proposalId': proposalId
        });
        final pickListId = 'pick-$proposalId';
        final now = DateTime.now();

        await tx.insert(
          'pick_lists',
          {
            'id': pickListId,
            'restock_order_id': proposalId,
            'warehouse_id': proposal.warehouseId,
            'picker_id': pickerId,
            'completed': 0,
            'created_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final updated =
            proposal.copyWith(status: RestockProposalStatus.picking);
        await tx.update(
          'restock_proposals',
          {'status': updated.status.name, 'body': jsonEncode(updated.toMap())},
          where: 'id=?',
          whereArgs: [proposalId],
        );
      });

  Future<void> completePicking({
    required String proposalId,
    required List<RestockProposalLine> pickedLines,
  }) =>
      _db.transaction((tx) async {
        final rows = await tx
            .query('restock_proposals', where: 'id=?', whereArgs: [proposalId]);
        if (rows.isEmpty) throw StateError('Restock order not found');

        final body =
            jsonDecode(rows.single['body'] as String) as Map<String, dynamic>;
        final proposal = RestockProposal.fromMap(body);

        if (![RestockProposalStatus.approved, RestockProposalStatus.picking]
            .contains(proposal.status)) {
          throw StateError('Order is not ready for picking');
        }
        if (pickedLines.length != proposal.lines.length ||
            pickedLines.map((line) => line.productId).toSet().length !=
                pickedLines.length ||
            pickedLines.any((line) => !proposal.lines.any((original) =>
                original.productId == line.productId &&
                line.pickedQuantity <= original.approvedQuantity))) {
          throw StateError('Picked quantities exceed approval');
        }
        await _queueProcurement(tx, 'manageRestockProposals', {
          'action': 'fulfill',
          'stage': 'pick',
          'proposalId': proposalId,
          'pickedLines': pickedLines.map((line) => line.toMap()).toList()
        });
        final now = DateTime.now();

        await tx.update(
          'pick_lists',
          {'completed': 1, 'completed_at': now.toIso8601String()},
          where: 'restock_order_id=?',
          whereArgs: [proposalId],
        );

        final updated = proposal.copyWith(
          status: RestockProposalStatus.picked,
          lines: pickedLines,
        );
        await tx.update(
          'restock_proposals',
          {'status': updated.status.name, 'body': jsonEncode(updated.toMap())},
          where: 'id=?',
          whereArgs: [proposalId],
        );
      });

  Future<void> completePacking({
    required String proposalId,
    required String packageCode,
    required String sealNotes,
  }) =>
      _db.transaction((tx) async {
        final rows = await tx
            .query('restock_proposals', where: 'id=?', whereArgs: [proposalId]);
        if (rows.isEmpty) throw StateError('Restock order not found');

        final body =
            jsonDecode(rows.single['body'] as String) as Map<String, dynamic>;
        final proposal = RestockProposal.fromMap(body);

        if (proposal.status != RestockProposalStatus.picked) {
          throw StateError('Pick the order before packing');
        }
        await _queueProcurement(tx, 'manageRestockProposals', {
          'action': 'fulfill',
          'stage': 'pack',
          'proposalId': proposalId,
          'packageCode': packageCode,
          'sealNotes': sealNotes
        });
        final now = DateTime.now();
        final manifestId = 'manifest-$proposalId';

        final totalItems =
            proposal.lines.fold(0, (sum, l) => sum + l.pickedQuantity);

        await tx.insert(
          'package_manifests',
          {
            'id': manifestId,
            'restock_order_id': proposalId,
            'package_code': packageCode,
            'total_items': totalItems,
            'seal_notes': sealNotes,
            'packed_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Deduct physical and reserved stock from warehouse
        for (final line in proposal.lines) {
          final qty = line.pickedQuantity;
          final stockRows = await tx.query(
            'warehouse_stock',
            where: 'warehouse_id=? AND product_id=?',
            whereArgs: [proposal.warehouseId, line.productId],
          );
          if (stockRows.isNotEmpty) {
            final phys = stockRows.single['physical_quantity'] as int;
            final res = stockRows.single['reserved_quantity'] as int;
            if (phys < qty || res < line.approvedQuantity) {
              throw StateError('Warehouse stock needs review');
            }
            await tx.update(
              'warehouse_stock',
              {
                'physical_quantity': phys - qty,
                'reserved_quantity': res - line.approvedQuantity,
              },
              where: 'warehouse_id=? AND product_id=?',
              whereArgs: [proposal.warehouseId, line.productId],
            );
          }
        }

        final updated = proposal.copyWith(status: RestockProposalStatus.packed);
        await tx.update(
          'restock_proposals',
          {'status': updated.status.name, 'body': jsonEncode(updated.toMap())},
          where: 'id=?',
          whereArgs: [proposalId],
        );
      });

  Future<void> saveDeliveryRun(DeliveryRun run) => _db.transaction((tx) async {
        await tx.insert(
          'delivery_runs',
          {
            'id': run.id,
            'driver_id': run.driverId,
            'driver_name': run.driverName,
            'vehicle_info': run.vehicleInfo,
            'warehouse_id': run.warehouseId,
            'status': run.status.name,
            'body': jsonEncode(run.toMap()),
            'created_at': run.createdAt.toIso8601String(),
            'started_at': run.startedAt?.toIso8601String(),
            'completed_at': run.completedAt?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final stop in run.stops) {
          await tx.insert(
            'delivery_stops',
            {
              'id': stop.id,
              'run_id': run.id,
              'sequence': stop.sequence,
              'destination_id': stop.destinationId,
              'destination_name': stop.destinationName,
              'destination_address': stop.destinationAddress,
              'status': stop.status.name,
              'body': jsonEncode(stop.toMap()),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          for (final item in stop.items) {
            await tx.insert(
              'delivery_stop_items',
              {
                'id': '${stop.id}_${item.productId}',
                'stop_id': stop.id,
                'product_id': item.productId,
                'quantity_ordered': item.quantityOrdered,
                'quantity_delivered': item.quantityDelivered,
                'quantity_returned': item.quantityReturned,
                'return_reason': item.returnReason,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          if (stop.proof != null) {
            await tx.insert(
              'delivery_proofs',
              {
                'id': stop.proof!.id,
                'stop_id': stop.id,
                'recipient_name': stop.proof!.recipientName,
                'recipient_role': stop.proof!.recipientRole,
                'signature_svg': stop.proof!.signatureSvg,
                'cash_collected_centavos': stop.proof!.cashCollectedCentavos,
                'delivered_at': stop.proof!.deliveredAt.toIso8601String(),
                'body': jsonEncode(stop.proof!.toMap()),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });

  Future<List<DeliveryRun>> listDeliveryRuns({
    String? driverId,
    DeliveryRunStatus? status,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (driverId != null) {
      whereClauses.add('driver_id = ?');
      whereArgs.add(driverId);
    }
    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.name);
    }
    final rows = await _db.query(
      'delivery_runs',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows
        .map((r) => DeliveryRun.fromMap(
            jsonDecode(r['body'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<DeliveryRun?> getDeliveryRun(String runId) async {
    final rows = await _db.query(
      'delivery_runs',
      where: 'id = ?',
      whereArgs: [runId],
    );
    if (rows.isEmpty) return null;
    return DeliveryRun.fromMap(
        jsonDecode(rows.single['body'] as String) as Map<String, dynamic>);
  }

  Future<void> updateStopStatus({
    required String runId,
    required String stopId,
    required DeliveryStopStatus status,
    String reason = '',
  }) =>
      _db.transaction((tx) async {
        final runRows = await tx.query(
          'delivery_runs',
          where: 'id = ?',
          whereArgs: [runId],
        );
        if (runRows.isEmpty) throw StateError('Delivery run not found: $runId');
        final run = DeliveryRun.fromMap(
            jsonDecode(runRows.single['body'] as String)
                as Map<String, dynamic>);

        final stop = run.stops.firstWhere((s) => s.id == stopId);
        if (stop.isCompleted ||
            ![DeliveryStopStatus.arrived, DeliveryStopStatus.failed]
                .contains(status)) {
          throw StateError(
              'Stop is already completed or transition is invalid');
        }
        if (status == DeliveryStopStatus.failed && reason.trim().isEmpty) {
          throw StateError('Failure reason required');
        }
        final operationId = sha256
            .convert(utf8.encode('$runId:$stopId:${status.name}'))
            .toString();
        await tx.insert(
            'delivery_outbox',
            {
              'id': operationId,
              'run': runId,
              'stop': stopId,
              'kind': 'status',
              'payload': jsonEncode({
                'operationId': operationId,
                'runId': runId,
                'stopId': stopId,
                'status': status.name,
                'reason': reason
              }),
              'status': 'pending'
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
        final updatedStops = run.stops.map((s) {
          if (s.id == stopId) {
            return s.copyWith(
                status: status,
                failureReason:
                    status == DeliveryStopStatus.failed ? reason : null);
          }
          return s;
        }).toList();

        final allFinished = updatedStops.every((s) =>
            s.status == DeliveryStopStatus.delivered ||
            s.status == DeliveryStopStatus.partiallyDelivered ||
            s.status == DeliveryStopStatus.failed ||
            s.status == DeliveryStopStatus.cancelled);

        var runStatus = run.status;
        if (allFinished) {
          runStatus = DeliveryRunStatus.completed;
        } else if (run.status == DeliveryRunStatus.dispatched) {
          runStatus = DeliveryRunStatus.inTransit;
        }

        final updatedRun = run.copyWith(
          status: runStatus,
          completedAt: allFinished ? DateTime.now() : run.completedAt,
          stops: updatedStops,
        );

        await tx.update(
          'delivery_stops',
          {
            'status': status.name,
            'body': jsonEncode(
                updatedStops.firstWhere((s) => s.id == stopId).toMap()),
          },
          where: 'id = ?',
          whereArgs: [stopId],
        );

        await tx.update(
          'delivery_runs',
          {
            'status': updatedRun.status.name,
            'completed_at': updatedRun.completedAt?.toIso8601String(),
            'body': jsonEncode(updatedRun.toMap()),
          },
          where: 'id = ?',
          whereArgs: [runId],
        );
      });

  Future<void> recordDeliveryProof({
    required String runId,
    required String stopId,
    required DeliveryProof proof,
    required List<DeliveryStopItem> items,
  }) =>
      _db.transaction((tx) async {
        final runRows = await tx.query(
          'delivery_runs',
          where: 'id = ?',
          whereArgs: [runId],
        );
        if (runRows.isEmpty) throw StateError('Delivery run not found: $runId');
        final run = DeliveryRun.fromMap(
            jsonDecode(runRows.single['body'] as String)
                as Map<String, dynamic>);

        final original = run.stops.firstWhere((s) => s.id == stopId);
        if (proof.stopId != stopId ||
            proof.recipientName.trim().isEmpty ||
            (proof.signatureSvg.isEmpty &&
                items.any((i) => i.quantityDelivered > 0)) ||
            proof.cashCollectedCentavos < 0 ||
            original.proof != null ||
            original.isCompleted ||
            items.length != original.items.length ||
            items.map((i) => i.productId).toSet().length != items.length) {
          throw StateError('Invalid or already settled delivery');
        }
        for (final item in items) {
          final manifest =
              original.items.firstWhere((i) => i.productId == item.productId);
          if (item.quantityOrdered != manifest.quantityOrdered ||
              item.unitCostCentavos != manifest.unitCostCentavos ||
              item.quantityDelivered < 0 ||
              item.quantityReturned < 0 ||
              item.quantityDelivered + item.quantityReturned !=
                  manifest.quantityOrdered ||
              (item.quantityReturned > 0 &&
                  (item.returnReason ?? '').trim().isEmpty)) {
            throw StateError('Delivery quantities do not match the manifest');
          }
        }
        final due = items.fold<int>(
            0, (n, i) => n + i.quantityDelivered * i.unitCostCentavos);
        if (proof.cashCollectedCentavos > due) {
          throw StateError('Collection exceeds delivered value');
        }
        await tx.insert('delivery_outbox', {
          'id': proof.id,
          'run': runId,
          'stop': stopId,
          'kind': 'proof',
          'status': 'pending',
          'payload': jsonEncode({
            'proof': proof.toMap(),
            'items': items.map((i) => i.toMap()).toList()
          })
        });
        final totalDelivered =
            items.fold(0, (sum, i) => sum + i.quantityDelivered);
        final totalReturned =
            items.fold(0, (sum, i) => sum + i.quantityReturned);
        final DeliveryStopStatus stopStatus;
        if (totalDelivered == 0 && totalReturned > 0) {
          stopStatus = DeliveryStopStatus.failed;
        } else if (totalDelivered < original.totalOrderedUnits) {
          stopStatus = DeliveryStopStatus.partiallyDelivered;
        } else {
          stopStatus = DeliveryStopStatus.delivered;
        }

        for (final item in items) {
          await tx.insert(
            'delivery_stop_items',
            {
              'id': '${stopId}_${item.productId}',
              'stop_id': stopId,
              'product_id': item.productId,
              'quantity_ordered': item.quantityOrdered,
              'quantity_delivered': item.quantityDelivered,
              'quantity_returned': item.quantityReturned,
              'return_reason': item.returnReason,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await tx.insert(
          'delivery_proofs',
          {
            'id': proof.id,
            'stop_id': stopId,
            'recipient_name': proof.recipientName,
            'recipient_role': proof.recipientRole,
            'signature_svg': proof.signatureSvg,
            'cash_collected_centavos': proof.cashCollectedCentavos,
            'delivered_at': proof.deliveredAt.toIso8601String(),
            'body': jsonEncode(proof.toMap()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final updatedStops = run.stops.map((s) {
          if (s.id == stopId) {
            return s.copyWith(
              status: stopStatus,
              items: items,
              proof: proof,
            );
          }
          return s;
        }).toList();

        final allFinished = updatedStops.every((s) =>
            s.status == DeliveryStopStatus.delivered ||
            s.status == DeliveryStopStatus.partiallyDelivered ||
            s.status == DeliveryStopStatus.failed ||
            s.status == DeliveryStopStatus.cancelled);

        final updatedRun = run.copyWith(
          status: allFinished ? DeliveryRunStatus.completed : run.status,
          completedAt: allFinished ? DateTime.now() : run.completedAt,
          stops: updatedStops,
        );

        await tx.update(
          'delivery_stops',
          {
            'status': stopStatus.name,
            'body': jsonEncode(
                updatedStops.firstWhere((s) => s.id == stopId).toMap()),
          },
          where: 'id = ?',
          whereArgs: [stopId],
        );

        await tx.update(
          'delivery_runs',
          {
            'status': updatedRun.status.name,
            'completed_at': updatedRun.completedAt?.toIso8601String(),
            'body': jsonEncode(updatedRun.toMap()),
          },
          where: 'id = ?',
          whereArgs: [runId],
        );
      });

  Future<EncryptedBackupArchive> exportBackupArchive({
    required String password,
  }) =>
      BackupArchiveService.exportEncryptedBackup(
        db: _db,
        merchantId: merchantId,
        branchId: branchId,
        password: password,
      );

  Future<DatabaseIntegrityReport> checkIntegrity() =>
      BackupArchiveService.checkDatabaseIntegrity(_db);

  /// Caller owns the returned store and must close it after inspection.
  /// Recovery never joins the active workspace or its automatic sync runner.
  Future<({InventoryStore store, RestoreResult result})>
      restoreRecoveryWorkspace({
    required EncryptedBackupArchive archive,
    required String password,
  }) async {
    await BackupArchiveService.verifyBackupArchive(
        archive: archive, password: password);
    if (archive.manifest.merchantId != merchantId ||
        archive.manifest.branchId != branchId ||
        archive.manifest.version != 2) {
      throw StateError(
          'A complete backup for this store and branch is required');
    }
    final random = Random.secure();
    final suffix = List.generate(
            4, (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'))
        .join();
    final path = '${_db.path}.recovery-$suffix';
    if (await _factory.databaseExists(path)) {
      throw StateError('Recovery location already exists');
    }
    final recovered = await InventoryStore.open(_factory, path,
        merchantId: merchantId, branchId: branchId);
    try {
      final result =
          await recovered.restoreBackup(archive: archive, password: password);
      return (store: recovered, result: result);
    } catch (_) {
      await recovered.close();
      await _factory.deleteDatabase(path);
      rethrow;
    }
  }

  Future<RestoreResult> restoreBackup({
    required EncryptedBackupArchive archive,
    required String password,
  }) =>
      BackupArchiveService.restoreAndVerifyBackup(
        db: _db,
        factory: _factory,
        archive: archive,
        password: password,
        expectedMerchantId: merchantId,
        expectedBranchId: branchId,
      );

  Future<InventoryValuationReport> generateInventoryValuation({
    DateTime? asOf,
  }) async {
    final now = asOf ?? DateTime.now();
    final rows = await _db.rawQuery('''
      SELECT p.id, p.sku, p.name, p.body, COALESCE(s.quantity, 0) as quantity
      FROM products p
      LEFT JOIN stock s ON s.product = p.id
      WHERE p.active = 1
      ORDER BY p.name COLLATE NOCASE ASC
    ''');

    final products = <ProductValuationRow>[];
    for (final row in rows) {
      final product = _product(row['body']);
      final unit = product.units.firstWhere(
        (u) => u.name == product.baseUnit,
        orElse: () => product.units.first,
      );
      final retailPrice = unit.priceCentavos;
      final qty = (await getProduct(product.id))!.quantity;

      products.add(ProductValuationRow(
        productId: product.id,
        sku: product.sku,
        name: product.name,
        unitName: unit.name,
        physicalQuantity: qty,
        costPriceCentavos: null,
        retailPriceCentavos: retailPrice,
      ));
    }

    int received = 0;
    int sold = 0;
    int returnedCustomer = 0;
    int transferredOut = 0;
    int transferredIn = 0;
    int adjusted = 0;

    try {
      final recRows = await _db.rawQuery(
        "SELECT SUM(delta) as total FROM ledger l JOIN local_order lo ON lo.id = l.id WHERE lo.kind = 'receiving'",
      );
      received = (recRows.firstOrNull?['total'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    try {
      final soldRows = await _db.rawQuery(
        "SELECT SUM(ABS(delta)) as total FROM sale_stock WHERE delta < 0",
      );
      sold = (soldRows.firstOrNull?['total'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    try {
      final refRows = await _db.rawQuery(
        "SELECT SUM(delta) as total FROM refund_stock WHERE delta > 0",
      );
      returnedCustomer = (refRows.firstOrNull?['total'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    try {
      final toRows = await _db.rawQuery(
        "SELECT SUM(ABS(delta)) as total FROM ledger l JOIN local_order lo ON lo.id = l.id WHERE lo.kind = 'transferOut'",
      );
      transferredOut = (toRows.firstOrNull?['total'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    try {
      final tiRows = await _db.rawQuery(
        "SELECT SUM(delta) as total FROM ledger l JOIN local_order lo ON lo.id = l.id WHERE lo.kind = 'transferIn'",
      );
      transferredIn = (tiRows.firstOrNull?['total'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    try {
      final adjRows = await _db.rawQuery(
        "SELECT SUM(delta) as total FROM ledger l JOIN local_order lo ON lo.id = l.id WHERE lo.kind IN ('adjustment', 'count')",
      );
      adjusted = (adjRows.firstOrNull?['total'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    final movementSummary = StockMovementSummary(
      receivedQuantity: received,
      soldQuantity: sold,
      returnedCustomerQuantity: returnedCustomer,
      transferredOutQuantity: transferredOut,
      transferredInQuantity: transferredIn,
      adjustedQuantity: adjusted,
    );

    return InventoryValuationReport(
      generatedAt: now,
      branchId: branchId,
      products: products,
      movementSummary: movementSummary,
    );
  }

  Future<List<SariNotification>> detectStockAlerts({
    int lowStockThreshold = 10,
    int expiryDaysThreshold = 14,
  }) async {
    final notifications = <SariNotification>[];
    final now = DateTime.now();

    // 1. Stock levels
    final products = await _db.rawQuery('''
      SELECT p.id, p.sku, p.name, p.body, COALESCE(s.quantity, 0) as quantity
      FROM products p
      LEFT JOIN stock s ON s.product = p.id
      WHERE p.active = 1
    ''');

    for (final row in products) {
      final qty = row['quantity'] as int;
      final name = row['name'] as String;
      final sku = row['sku'] as String;
      final prodId = row['id'] as String;

      if (qty <= 0) {
        notifications.add(SariNotification(
          id: 'out_of_stock_$prodId',
          title: 'Out of Stock: $name',
          message: 'Product $name ($sku) has 0 units remaining in stock.',
          category: NotificationCategory.stock,
          severity: NotificationSeverity.critical,
          createdAt: now,
          actionPayload: {'productId': prodId, 'sku': sku, 'quantity': qty},
        ));
      } else if (qty <= lowStockThreshold) {
        notifications.add(SariNotification(
          id: 'low_stock_$prodId',
          title: 'Low Stock: $name',
          message: 'Only $qty units remaining for $name ($sku).',
          category: NotificationCategory.stock,
          severity: NotificationSeverity.warning,
          createdAt: now,
          actionPayload: {'productId': prodId, 'sku': sku, 'quantity': qty},
        ));
      }
    }

    // 2. Expiring batches
    try {
      final batches = await _db.rawQuery('''
        SELECT b.id, b.product, b.batch_number, b.expiry_date, b.quantity, p.name, p.sku
        FROM batches b
        JOIN products p ON p.id = b.product
        WHERE b.quantity > 0
      ''');
      final cutoff = now.add(Duration(days: expiryDaysThreshold));
      for (final b in batches) {
        final expiryStr = b['expiry_date'] as String;
        final exp = DateTime.tryParse(expiryStr);
        if (exp != null && exp.isBefore(cutoff)) {
          final isExpired = exp.isBefore(now);
          final name = b['name'] as String;
          final batchNo = b['batch_number'] as String;
          final bQty = b['quantity'] as int;
          notifications.add(SariNotification(
            id: 'batch_${b['id']}',
            title:
                isExpired ? 'Expired Batch: $name' : 'Near-Expiry Batch: $name',
            message: isExpired
                ? 'Batch $batchNo ($bQty units) expired on ${exp.toIso8601String().split('T').first}.'
                : 'Batch $batchNo ($bQty units) expires in ${exp.difference(now).inDays} days (${exp.toIso8601String().split('T').first}).',
            category: NotificationCategory.expiry,
            severity: isExpired
                ? NotificationSeverity.critical
                : NotificationSeverity.warning,
            createdAt: now,
            actionPayload: {
              'batchId': b['id'],
              'productId': b['product'],
              'batchNumber': batchNo,
              'quantity': bQty,
              'expiryDate': expiryStr,
            },
          ));
        }
      }
    } catch (_) {}

    // 3. Unsynced transactions
    try {
      final outboxRows = await _db.rawQuery(
        "SELECT COUNT(*) as count FROM outbox WHERE status = 'pending'",
      );
      final checkoutRows = await _db.rawQuery(
        "SELECT COUNT(*) as count FROM checkout_outbox WHERE status = 'pending'",
      );
      final pendingCount =
          ((outboxRows.firstOrNull?['count'] as num?)?.toInt() ?? 0) +
              ((checkoutRows.firstOrNull?['count'] as num?)?.toInt() ?? 0);
      if (pendingCount > 0) {
        notifications.add(SariNotification(
          id: 'sync_pending_${now.millisecondsSinceEpoch ~/ 60000}',
          title: 'Pending Sync Items',
          message: '$pendingCount transactions waiting to sync with cloud.',
          category: NotificationCategory.sync,
          severity: NotificationSeverity.info,
          createdAt: now,
          actionPayload: {'pendingCount': pendingCount},
        ));
      }
    } catch (_) {}

    return notifications;
  }
}
