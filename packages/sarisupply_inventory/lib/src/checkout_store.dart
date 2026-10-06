part of 'inventory_store.dart';

final class CheckoutStore {
  CheckoutStore._(this._inventory);
  final InventoryStore _inventory;
  Database get _db => _inventory._db;
  static Future<void> migrate(DatabaseExecutor db) async {
    await db
        .execute('ALTER TABLE products ADD COLUMN catalog_sequence INTEGER');
    for (final sql in [
      'CREATE TABLE local_order(ordinal INTEGER PRIMARY KEY AUTOINCREMENT,id TEXT NOT NULL UNIQUE,kind TEXT NOT NULL)',
      'CREATE TABLE checkout_events(id TEXT PRIMARY KEY,device TEXT NOT NULL,cashier TEXT NOT NULL,shift TEXT NOT NULL,ordinal INTEGER NOT NULL,kind TEXT NOT NULL,body TEXT NOT NULL,UNIQUE(shift,ordinal))',
      'CREATE TABLE checkout_sales(id TEXT PRIMARY KEY REFERENCES checkout_events(id),body TEXT NOT NULL)',
      'CREATE TABLE checkout_tenders(id TEXT PRIMARY KEY REFERENCES checkout_sales(id),body TEXT NOT NULL)',
      'CREATE TABLE sale_stock(sale TEXT NOT NULL REFERENCES checkout_sales(id),product TEXT NOT NULL REFERENCES products(id),delta INTEGER NOT NULL,PRIMARY KEY(sale,product))',
      'CREATE TABLE cash_entries(id TEXT PRIMARY KEY REFERENCES checkout_events(id),shift TEXT NOT NULL,delta INTEGER NOT NULL)',
      'CREATE TABLE checkout_shifts(id TEXT PRIMARY KEY,device TEXT NOT NULL,open INTEGER NOT NULL,body TEXT NOT NULL)',
      'CREATE UNIQUE INDEX one_open_shift ON checkout_shifts(device) WHERE open=1',
      'CREATE TABLE checkout_outbox(id TEXT PRIMARY KEY REFERENCES checkout_events(id),status TEXT NOT NULL,sequence INTEGER,message TEXT)',
      'CREATE INDEX checkout_pending ON checkout_outbox(status)',
      'CREATE INDEX sale_stock_product ON sale_stock(product)',
      'CREATE TABLE checkout_drafts(device TEXT NOT NULL,cashier TEXT NOT NULL,body TEXT NOT NULL,PRIMARY KEY(device,cashier))',
    ]) {
      await db.execute(sql);
    }
    for (final row in await db.query('ledger', orderBy: 'rowid')) {
      await db.insert('local_order', {'id': row['id'], 'kind': 'count'});
    }
    for (final table in [
      'checkout_events',
      'checkout_sales',
      'checkout_tenders',
      'sale_stock',
      'cash_entries'
    ]) {
      for (final action in ['UPDATE', 'DELETE']) {
        await db.execute(
            "CREATE TRIGGER ${table}_no_${action.toLowerCase()} BEFORE $action ON $table BEGIN SELECT RAISE(ABORT,'Immutable finance'); END");
      }
    }
  }

  static Future<void> migrateRecovery(DatabaseExecutor db) => db.execute(
      'CREATE TABLE checkout_recovery(device TEXT NOT NULL,cashier TEXT NOT NULL,receipt TEXT NOT NULL REFERENCES checkout_sales(id),seen INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(device,cashier))');

  void _scope(CheckoutScope s) {
    if (s.merchantId != _inventory.merchantId ||
        s.branchId != _inventory.branchId) {
      throw StateError('Checkout scope mismatch');
    }
  }

  static Map<String, Object?> _body(Object? raw) =>
      checkoutMap(jsonDecode(raw as String));
  Future<CashierShift?> _shift(DatabaseExecutor db, String id) async {
    final rows =
        await db.query('checkout_shifts', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty
        ? null
        : CashierShift.fromMap(_body(rows.single['body']));
  }

  Future<CashierShift?> activeShift(String deviceId) async {
    final rows = await _db.query('checkout_shifts',
        where: 'device=? AND open=1', whereArgs: [deviceId]);
    return rows.isEmpty
        ? null
        : CashierShift.fromMap(_body(rows.single['body']));
  }

  Future<bool> _replay(DatabaseExecutor tx, CheckoutIntent i) async {
    _scope(i.scope);
    final rows =
        await tx.query('checkout_events', where: 'id=?', whereArgs: [i.id]);
    if (rows.isEmpty) return false;
    if (rows.single['body'] != i.fingerprint) {
      throw StateError('Operation ID has another payload');
    }
    return true;
  }

  Future<void> _event(DatabaseExecutor tx, CheckoutIntent i) async {
    await tx.insert('checkout_events', {
      'id': i.id,
      'device': i.scope.deviceId,
      'cashier': i.scope.cashierId,
      'shift': i.shiftId,
      'ordinal': i.ordinal,
      'kind': i.kind,
      'body': i.fingerprint
    });
    await tx.insert('local_order', {'id': i.id, 'kind': i.kind});
    await tx.insert('checkout_outbox', {'id': i.id, 'status': 'pending'});
  }

  Future<void> _putShift(DatabaseExecutor tx, CashierShift shift) async {
    await tx.insert(
        'checkout_shifts',
        {
          'id': shift.id,
          'device': shift.scope.deviceId,
          'open': shift.closed ? 0 : 1,
          'body': jsonEncode(shift.toMap())
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> openShift(CheckoutIntent i) => _db.transaction((tx) async {
        if (i.kind != 'openShift' || i.ordinal != 1 || i.id != i.shiftId) {
          throw StateError('Invalid opening');
        }
        if (await _replay(tx, i)) return;
        final rows = await tx.query('checkout_shifts',
            where: 'device=? AND open=1', whereArgs: [i.scope.deviceId]);
        if (rows.isNotEmpty) throw StateError('Close the current shift first');
        final shift = CashierShift(
            id: i.shiftId,
            scope: i.scope,
            openingFloatCentavos: i.payload['floatCentavos'] as int);
        await _event(tx, i);
        await _putShift(tx, shift);
        await tx.insert('cash_entries', {
          'id': i.id,
          'shift': i.shiftId,
          'delta': shift.openingFloatCentavos
        });
      });
  Future<void> recordCashMovement(CheckoutIntent i) =>
      _mutation(i, ['cashIn', 'cashOut']);
  Future<void> closeShift(CheckoutIntent i) => _mutation(i, ['closeShift']);
  Future<void> _mutation(CheckoutIntent i, List<String> kinds) =>
      _db.transaction((tx) async {
        if (!kinds.contains(i.kind)) throw StateError('Invalid cash operation');
        if (await _replay(tx, i)) return;
        final shift = await _shift(tx, i.shiftId);
        if (shift == null) throw StateError('Open a shift first');
        final next = shift.apply(i);
        await _event(tx, i);
        await _putShift(tx, next);
        await tx.insert('cash_entries', {
          'id': i.id,
          'shift': i.shiftId,
          'delta': i.kind == 'closeShift'
              ? 0
              : (i.payload['amountCentavos'] as int) *
                  (i.kind == 'cashOut' ? -1 : 1)
        });
      });
  Future<void> saveDraft(CheckoutDraft draft) => _db.transaction((tx) async {
        _scope(draft.scope);
        final shift = await _shift(tx, draft.shiftId);
        if (shift == null ||
            shift.closed ||
            !shift.scope.sameCashier(draft.scope)) {
          throw StateError('Shift unavailable');
        }
        final old = await tx.query('checkout_drafts',
            where: 'device=? AND cashier=?',
            whereArgs: [draft.scope.deviceId, draft.scope.cashierId]);
        final previous = old.isEmpty
            ? null
            : CheckoutDraft.fromMap(_body(old.single['body']));
        if (previous?.paymentAttemptId.isNotEmpty == true) {
          if (draft.paymentAttemptId != previous!.paymentAttemptId ||
              draft.shiftId != previous.shiftId ||
              jsonEncode(draft.lines.map((line) => line.toMap()).toList()) !=
                  jsonEncode(
                      previous.lines.map((line) => line.toMap()).toList()) ||
              draft.tenderKind != previous.tenderKind ||
              draft.qrReference != previous.qrReference ||
              draft.received != previous.received ||
              draft.qrConfirmed != previous.qrConfirmed) {
            throw StateError('Recover the reserved payment before editing');
          }
        }
        if (old.isNotEmpty) {
          final frozen = previous!.frozenSale;
          if (frozen != null &&
              jsonEncode(frozen.toMap()) !=
                  jsonEncode(draft.frozenSale?.toMap())) {
            throw StateError('Complete or recover the pending payment first');
          }
        }
        final frozen = draft.frozenSale;
        if (frozen != null &&
            (!frozen.scope.sameCashier(draft.scope) ||
                frozen.shiftId != draft.shiftId ||
                frozen.ordinal != shift.lastOrdinal + 1 ||
                (draft.paymentAttemptId.isNotEmpty &&
                    frozen.id != draft.paymentAttemptId) ||
                jsonEncode(frozen.lines.map((l) => l.toMap()).toList()) !=
                    jsonEncode(draft.lines.map((l) => l.toMap()).toList()))) {
          throw StateError('Invalid frozen payment');
        }
        if ((frozen != null || draft.paymentAttemptId.isNotEmpty) &&
            previous?.frozenSale == null &&
            (previous?.paymentAttemptId.isEmpty ?? true)) {
          // A quoted price is frozen for recovery, not silently replaced by new catalog data.
          for (final line in draft.lines) {
            final products = await tx.query('products',
                where: 'id=? AND active=1', whereArgs: [line.productId]);
            if (products.isEmpty) throw StateError('Product unavailable');
            final p = InventoryStore._product(products.single['body']);
            if (p.revision != line.catalogRevision ||
                products.single['catalog_sequence'] != line.catalogSequence ||
                p.sku != line.sku ||
                p.name != line.name ||
                !p.units.any((u) =>
                    u.name == line.unit &&
                    u.factor == line.factor &&
                    u.priceCentavos == line.priceCentavos)) {
              throw StateError('Prices changed; review this cart');
            }
          }
        }
        await tx.insert(
            'checkout_drafts',
            {
              'device': draft.scope.deviceId,
              'cashier': draft.scope.cashierId,
              'body': jsonEncode(draft.toMap())
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      });
  Future<CheckoutDraft?> readDraft(String deviceId, String cashierId) async {
    final rows = await _db.query('checkout_drafts',
        where: 'device=? AND cashier=?', whereArgs: [deviceId, cashierId]);
    return rows.isEmpty
        ? null
        : CheckoutDraft.fromMap(_body(rows.single['body']));
  }

  Future<void> cancelReservedDraft(
          String deviceId, String cashierId, String attemptId) =>
      _db.transaction((tx) async {
        final rows = await tx.query('checkout_drafts',
            where: 'device=? AND cashier=?', whereArgs: [deviceId, cashierId]);
        if (rows.isEmpty) return;
        final draft = CheckoutDraft.fromMap(_body(rows.single['body']));
        if (draft.frozenSale != null ||
            attemptId.isEmpty ||
            draft.paymentAttemptId != attemptId) {
          throw StateError('Payment is already frozen or changed');
        }
        await tx.update('checkout_drafts',
            {'body': jsonEncode(draft.copyWith(paymentAttemptId: '').toMap())},
            where: 'device=? AND cashier=?', whereArgs: [deviceId, cashierId]);
        await tx.update('credit_grants', {'authoritative': 0},
            where: 'id=?', whereArgs: ['credit-$attemptId']);
      });

  Future<void> discardDraft(String deviceId, String cashierId) =>
      _db.transaction((tx) async {
        final rows = await tx.query('checkout_drafts',
            where: 'device=? AND cashier=?', whereArgs: [deviceId, cashierId]);
        final draft = rows.isEmpty
            ? null
            : CheckoutDraft.fromMap(_body(rows.single['body']));
        if (draft?.frozenSale != null ||
            (draft?.paymentAttemptId.isNotEmpty ?? false)) {
          throw StateError('Recover the payment before discarding');
        }
        await tx.delete('checkout_drafts',
            where: 'device=? AND cashier=?', whereArgs: [deviceId, cashierId]);
      });
  Future<CheckoutSale?> sale(String id) async {
    final rows =
        await _db.query('checkout_sales', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty
        ? null
        : CheckoutSale.fromMap(_body(rows.single['body']));
  }

  Future<CheckoutSale> completeSale(CheckoutSale sale) =>
      _db.transaction((tx) async {
        final i = sale.intent;
        if (await _replay(tx, i)) return sale;
        final shift = await _shift(tx, sale.shiftId);
        if (shift == null) throw StateError('Open a shift first');
        final next = shift.apply(i);
        final drafts = await tx.query('checkout_drafts',
            where: 'device=? AND cashier=?',
            whereArgs: [sale.scope.deviceId, sale.scope.cashierId]);
        if (drafts.isEmpty ||
            jsonEncode(CheckoutDraft.fromMap(_body(drafts.single['body']))
                    .frozenSale
                    ?.toMap()) !=
                jsonEncode(sale.toMap())) {
          throw StateError('Save the payment draft before checkout');
        }
        await _event(tx, i);
        await tx.insert('checkout_sales',
            {'id': sale.id, 'body': jsonEncode(sale.toMap())});
        await tx.insert('checkout_tenders',
            {'id': sale.id, 'body': jsonEncode(sale.tender.toMap())});
        for (final entry in sale.baseQuantities.entries) {
          await tx.insert('sale_stock',
              {'sale': sale.id, 'product': entry.key, 'delta': -entry.value});
        }
        await tx.insert('cash_entries', {
          'id': sale.id,
          'shift': sale.shiftId,
          'delta': sale.tender.kind == 'cash' ? sale.totalCentavos : 0
        });
        if (sale.tender.kind == 'credit') {
          final custRows = await tx.query('customers',
              where: 'id=?', whereArgs: [sale.tender.reference]);
          if (custRows.isEmpty) throw StateError('Customer not found');
          final custRow = custRows.single;
          final cust = CustomerAccount(
            id: custRow['id'] as String,
            name: custRow['name'] as String,
            phone: custRow['phone'] as String,
            creditLimitCentavos: custRow['credit_limit'] as int,
            balanceCentavos: custRow['balance'] as int,
            active: (custRow['active'] as int) == 1,
          );
          if (!cust.canCharge(sale.totalCentavos)) {
            throw StateError('Credit limit exceeded');
          }
          final grantRows = await tx.query('credit_grants',
              where:
                  'id=? AND customer_id=? AND device_id=? AND authoritative=1',
              whereArgs: [
                sale.tender.creditGrantId,
                cust.id,
                sale.scope.deviceId
              ]);
          if (grantRows.isEmpty) {
            throw StateError(
                'Connect to reserve customer credit before charging');
          }
          if (grantRows.isNotEmpty) {
            final grantRow = grantRows.single;
            if (grantRow['id'] != sale.tender.creditGrantId) {
              throw StateError('Credit reservation does not match payment');
            }
            final grant = CreditAllowanceGrant(
              id: grantRow['id'] as String,
              customerId: grantRow['customer_id'] as String,
              deviceId: grantRow['device_id'] as String,
              allowedCreditCentavos: grantRow['allowed'] as int,
              usedCreditCentavos: grantRow['used'] as int,
              expiresAt: DateTime.parse(grantRow['expires_at'] as String),
            );
            if (!grant.canChargeOffline(sale.totalCentavos, sale.occurredAt)) {
              throw StateError('Offline credit allowance exceeded or expired');
            }
            await tx.update('credit_grants',
                {'used': grant.usedCreditCentavos + sale.totalCentavos},
                where: 'id=?', whereArgs: [grant.id]);
          }
          await tx.update('customers',
              {'balance': cust.balanceCentavos + sale.totalCentavos},
              where: 'id=?', whereArgs: [cust.id]);
        }
        await _putShift(tx, next);
        await tx.insert(
            'checkout_recovery',
            {
              'device': sale.scope.deviceId,
              'cashier': sale.scope.cashierId,
              'receipt': sale.id,
              'seen': 0
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
        await tx.delete('checkout_drafts',
            where: 'device=? AND cashier=?',
            whereArgs: [sale.scope.deviceId, sale.scope.cashierId]);
        return sale;
      });
  Future<CheckoutSale?> unseenReceipt(String deviceId, String cashierId) async {
    final rows = await _db.query('checkout_recovery',
        where: 'device=? AND cashier=? AND seen=0',
        whereArgs: [deviceId, cashierId]);
    return rows.isEmpty ? null : sale(rows.single['receipt'] as String);
  }

  Future<void> markReceiptSeen(
      String deviceId, String cashierId, String receiptId) async {
    await _db.update('checkout_recovery', {'seen': 1},
        where: 'device=? AND cashier=? AND receipt=?',
        whereArgs: [deviceId, cashierId, receiptId]);
  }

  Future<CheckoutIntent?> operation(String id) async {
    final rows = await _db.rawQuery(
        'SELECT e.body,o.status,o.sequence,o.message FROM checkout_events e JOIN checkout_outbox o ON o.id=e.id WHERE e.id=?',
        [id]);
    if (rows.isEmpty) return null;
    final r = rows.single;
    return CheckoutIntent.fromMap(_body(r['body']),
        status: r['status'] as String,
        sequence: r['sequence'] as int?,
        message: r['message'] as String?);
  }

  Future<List<CheckoutSale>> receipts(
      {String query = '', String? cursor, int limit = 50}) async {
    if (limit < 1 ||
        limit > 50 ||
        (cursor != null &&
            (int.tryParse(cursor) == null || int.parse(cursor) < 1))) {
      throw ArgumentError('Invalid receipt page');
    }
    final text = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await _db.rawQuery(
        "SELECT s.body FROM checkout_sales s JOIN local_order l ON l.id=s.id WHERE s.body LIKE ? ESCAPE '\\' ${cursor == null ? '' : 'AND l.ordinal<?'} ORDER BY l.ordinal DESC LIMIT ?",
        ['%$text%', if (cursor != null) int.parse(cursor), limit]);
    return rows.map((r) => CheckoutSale.fromMap(_body(r['body']))).toList();
  }

  Future<String?> receiptCursor(String id) async {
    final rows = await _db.query('local_order',
        columns: ['ordinal'], where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.single['ordinal'].toString();
  }

  Future<int> unsettledCount() async => (await _db.rawQuery(
          "SELECT COUNT(*) AS n FROM checkout_outbox WHERE status IN ('pending','conflict','blocked') OR (status='accepted' AND sequence>?)",
          [await _inventory.stockCursor()]))
      .single['n'] as int;

  Future<List<CheckoutIntent>> pendingIntents({int limit = 20}) async {
    if (limit < 1 || limit > 20) throw ArgumentError('Invalid upload bound');
    final rows = await _db.rawQuery(
        "SELECT e.body,o.status,o.sequence,o.message FROM checkout_events e JOIN checkout_outbox o ON o.id=e.id JOIN local_order l ON l.id=e.id WHERE o.status IN ('pending','conflict','blocked') ORDER BY l.ordinal LIMIT ?",
        [limit]);
    return rows
        .map((r) => CheckoutIntent.fromMap(_body(r['body']),
            status: r['status'] as String,
            sequence: r['sequence'] as int?,
            message: r['message'] as String?))
        .toList();
  }

  Future<void> retryOwnerApprovedReversal(String id) =>
      _db.transaction((tx) async {
        final rows = await tx.rawQuery(
            'SELECT e.body,o.status,o.message FROM checkout_events e JOIN checkout_outbox o ON o.id=e.id WHERE e.id=?',
            [id]);
        if (rows.length != 1) throw StateError('Reversal not found');
        final intent = CheckoutIntent.fromMap(_body(rows.single['body']));
        if (!['refund', 'voidSale'].contains(intent.kind)) {
          throw StateError('Select a reversal');
        }
        if (rows.single['status'] == 'pending') return;
        if (rows.single['status'] != 'blocked' ||
            rows.single['message'] !=
                'Owner approval required for this exact refund or void') {
          throw StateError('This operation requires a different review');
        }
        await tx.update(
            'checkout_outbox', {'status': 'pending', 'message': null},
            where: 'id=?', whereArgs: [id]);
      });

  Future<List<CheckoutIntent>> operations({int limit = 50}) async {
    final rows = await _db.rawQuery(
        'SELECT e.body,o.status,o.sequence,o.message FROM checkout_events e JOIN checkout_outbox o ON o.id=e.id JOIN local_order l ON l.id=e.id ORDER BY l.ordinal DESC LIMIT ?',
        [limit.clamp(1, 50)]);
    return rows
        .map((r) => CheckoutIntent.fromMap(_body(r['body']),
            status: r['status'] as String,
            sequence: r['sequence'] as int?,
            message: r['message'] as String?))
        .toList();
  }

  Future<void> acknowledge(CheckoutAck ack) => _db.transaction((tx) async {
        final rows = await tx.rawQuery(
            'SELECT e.kind,o.* FROM checkout_events e JOIN checkout_outbox o ON o.id=e.id WHERE e.id=?',
            [ack.operationId]);
        if (rows.isEmpty ||
            !['accepted', 'duplicate', 'conflict', 'blocked']
                .contains(ack.status)) {
          throw const FormatException('Invalid checkout acknowledgement');
        }
        final row = rows.single;
        final accepted = ['accepted', 'duplicate'].contains(ack.status);
        if (accepted &&
            ['sale', 'refund', 'voidSale'].contains(row['kind']) &&
            (ack.sequence == null || ack.sequence! < 1)) {
          throw const FormatException('Missing stock sequence');
        }
        if (!['sale', 'refund', 'voidSale'].contains(row['kind']) &&
            ack.sequence != null) {
          throw const FormatException('Unexpected stock sequence');
        }
        if (row['status'] == 'accepted') {
          if (accepted && row['sequence'] != ack.sequence) {
            throw const FormatException('Acknowledgement changed');
          }
          return;
        }
        if (accepted &&
            ack.sequence != null &&
            ack.sequence! <= await _inventory._cursor(tx, 'stock')) {
          throw const FormatException(
              'Acknowledgement predates feed without matching operation');
        }
        await tx.update(
            'checkout_outbox',
            {
              'status': ack.status == 'duplicate' ? 'accepted' : ack.status,
              'sequence': ack.sequence,
              'message': ack.message
            },
            where: 'id=?',
            whereArgs: [ack.operationId]);
      });
  Future<int?> catalogSequence(String productId) async {
    final rows = await _db.query('products',
        columns: ['catalog_sequence'], where: 'id=?', whereArgs: [productId]);
    return rows.isEmpty ? null : rows.single['catalog_sequence'] as int?;
  }

  Future<void> resolveQuote(CatalogChange change) =>
      _db.transaction((tx) async {
        final rows = await tx
            .query('products', where: 'id=?', whereArgs: [change.product.id]);
        if (change.sequence < 1 ||
            rows.isEmpty ||
            jsonEncode(InventoryStore._product(rows.single['body']).toMap()) !=
                jsonEncode(change.product.toMap())) {
          throw StateError('Quote changed; sync and review');
        }
        await tx.update('products', {'catalog_sequence': change.sequence},
            where: 'id=?', whereArgs: [change.product.id]);
      });

  Future<void> _reverseCredit(
      Transaction tx, CheckoutSale original, int amount) async {
    if (original.tender.kind != 'credit') return;
    final rows = await tx.query('customers',
        where: 'id=?', whereArgs: [original.tender.reference]);
    if (rows.isEmpty || (rows.single['balance'] as int) < amount) {
      throw StateError('Credit was repaid or changed; Owner review required');
    }
    await tx.update(
        'customers', {'balance': (rows.single['balance'] as int) - amount},
        where: 'id=?', whereArgs: [original.tender.reference]);
    // A used reservation stays consumed. A return cannot create reusable credit.
  }

  Future<void> recordRefund(RefundIntent refund) => _db.transaction((tx) async {
        if (refund.authorizedByCashierId != refund.scope.cashierId) {
          throw ArgumentError('Refund authorizer must match signed-in cashier');
        }
        final i = refund.toCheckoutIntent();
        if (await _replay(tx, i)) return;
        final shift = await _shift(tx, refund.shiftId);
        if (shift == null || shift.closed) {
          throw StateError('Open shift required');
        }
        final next = shift.apply(i);

        final saleRows = await tx.query('checkout_sales',
            where: 'id=?', whereArgs: [refund.originalSaleId]);
        if (saleRows.isEmpty) {
          throw StateError('Original sale not found');
        }
        final originalSale =
            CheckoutSale.fromMap(_body(saleRows.single['body']));

        final voidRows = await tx.query('checkout_voids',
            where: 'original_sale=?', whereArgs: [refund.originalSaleId]);
        if (voidRows.isNotEmpty) {
          throw StateError('Sale is already voided');
        }

        final existingRefundRows = await tx.query('checkout_refunds',
            where: 'original_sale=?', whereArgs: [refund.originalSaleId]);
        var totalRefundedCentavos = 0;
        for (final row in existingRefundRows) {
          final priorMap = _body(row['body']);
          if (priorMap.containsKey('totalRefundCentavos')) {
            final priorRefund = RefundIntent.fromMap(priorMap);
            totalRefundedCentavos += priorRefund.totalRefundCentavos;
          }
        }

        String lineKey(String productId, String sku, String name, String unit,
                int factor, int price) =>
            jsonEncode([productId, sku, name, unit, factor, price]);
        final purchased = <String, int>{};
        for (final line in originalSale.lines) {
          final key = lineKey(line.productId, line.sku, line.name, line.unit,
              line.factor, line.priceCentavos);
          purchased[key] = (purchased[key] ?? 0) + line.quantity;
        }
        final returned = <String, int>{};
        for (final row in existingRefundRows) {
          final priorMap = _body(row['body']);
          if (!priorMap.containsKey('totalRefundCentavos')) continue;
          for (final line in RefundIntent.fromMap(priorMap).lines) {
            final key = lineKey(line.productId, line.sku, line.name, line.unit,
                line.factor, line.priceCentavos);
            returned[key] = (returned[key] ?? 0) + line.quantity;
          }
        }
        if (refund.tenderKind != originalSale.tender.kind) {
          throw ArgumentError('Refund tender must match original receipt');
        }
        for (final line in refund.lines) {
          final key = lineKey(line.productId, line.sku, line.name, line.unit,
              line.factor, line.priceCentavos);
          returned[key] = (returned[key] ?? 0) + line.quantity;
          if (!purchased.containsKey(key) || returned[key]! > purchased[key]!) {
            throw ArgumentError('Refund line exceeds original receipt');
          }
        }

        if (totalRefundedCentavos + refund.totalRefundCentavos >
            originalSale.totalCentavos) {
          throw ArgumentError('Refund exceeds total paid amount');
        }

        await _reverseCredit(tx, originalSale, refund.totalRefundCentavos);
        await _event(tx, i);

        await tx.insert('checkout_refunds', {
          'id': refund.id,
          'original_sale': refund.originalSaleId,
          'body': jsonEncode(refund.toMap()),
        });

        for (final entry in refund.baseQuantities.entries) {
          await tx.insert('refund_stock', {
            'refund': refund.id,
            'product': entry.key,
            'delta': entry.value,
          });
        }

        if (refund.tenderKind == 'cash') {
          await tx.insert('cash_entries', {
            'id': refund.id,
            'shift': refund.shiftId,
            'delta': -refund.totalRefundCentavos,
          });
        }

        await _putShift(tx, next);
      });

  Future<void> voidSale(VoidIntent voidIntent) => _db.transaction((tx) async {
        if (voidIntent.authorizedByCashierId != voidIntent.scope.cashierId) {
          throw ArgumentError('Void authorizer must match signed-in cashier');
        }
        final i = voidIntent.toCheckoutIntent();
        if (await _replay(tx, i)) return;
        final shift = await _shift(tx, voidIntent.shiftId);
        if (shift == null || shift.closed) {
          throw StateError('Open shift required');
        }
        final next = shift.apply(i);

        final saleRows = await tx.query('checkout_sales',
            where: 'id=?', whereArgs: [voidIntent.originalSaleId]);
        if (saleRows.isEmpty) {
          throw StateError('Original sale not found');
        }
        final originalSale =
            CheckoutSale.fromMap(_body(saleRows.single['body']));
        if (voidIntent.shiftId != originalSale.shiftId ||
            voidIntent.tenderKind != originalSale.tender.kind ||
            voidIntent.voidCentavos != originalSale.totalCentavos) {
          throw ArgumentError(
              'Void must reverse the original receipt tender and total');
        }

        final voidRows = await tx.query('checkout_voids',
            where: 'original_sale=?', whereArgs: [voidIntent.originalSaleId]);
        if (voidRows.isNotEmpty) {
          throw StateError('Sale is already voided');
        }

        final existingRefundRows = await tx.query('checkout_refunds',
            where: 'original_sale=?', whereArgs: [voidIntent.originalSaleId]);
        if (existingRefundRows.isNotEmpty) {
          throw StateError('Cannot void a partially refunded sale');
        }

        await _reverseCredit(tx, originalSale, voidIntent.voidCentavos);
        await _event(tx, i);

        await tx.insert('checkout_voids', {
          'id': voidIntent.id,
          'original_sale': voidIntent.originalSaleId,
          'body': jsonEncode(voidIntent.toMap()),
        });

        await tx.insert('checkout_refunds', {
          'id': voidIntent.id,
          'original_sale': voidIntent.originalSaleId,
          'body': jsonEncode(voidIntent.toMap()),
        });

        for (final entry in originalSale.baseQuantities.entries) {
          await tx.insert('refund_stock', {
            'refund': voidIntent.id,
            'product': entry.key,
            'delta': entry.value,
          });
        }

        if (originalSale.tender.kind == 'cash') {
          await tx.insert('cash_entries', {
            'id': voidIntent.id,
            'shift': voidIntent.shiftId,
            'delta': -originalSale.totalCentavos,
          });
        }

        await _putShift(tx, next);
      });

  Future<void> saveCustomer(CustomerAccount customer) => _db.insert(
      'customers',
      {
        'id': customer.id,
        'name': customer.name,
        'phone': customer.phone,
        'credit_limit': customer.creditLimitCentavos,
        'balance': customer.balanceCentavos,
        'active': customer.active ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<CustomerAccount?> getCustomer(String customerId) async {
    final rows =
        await _db.query('customers', where: 'id=?', whereArgs: [customerId]);
    if (rows.isEmpty) return null;
    return CustomerAccount(
      id: rows.single['id'] as String,
      name: rows.single['name'] as String,
      phone: rows.single['phone'] as String,
      creditLimitCentavos: rows.single['credit_limit'] as int,
      balanceCentavos: rows.single['balance'] as int,
      active: (rows.single['active'] as int) == 1,
    );
  }

  Future<List<CustomerAccount>> listCustomers() async {
    final rows = await _db.query('customers', orderBy: 'name ASC');
    return rows
        .map((r) => CustomerAccount(
              id: r['id'] as String,
              name: r['name'] as String,
              phone: r['phone'] as String,
              creditLimitCentavos: r['credit_limit'] as int,
              balanceCentavos: r['balance'] as int,
              active: (r['active'] as int) == 1,
            ))
        .toList();
  }

  Future<void> saveCreditGrant(CreditAllowanceGrant grant,
          {bool serverIssued = false}) =>
      _db.insert(
          'credit_grants',
          {
            'id': grant.id,
            'customer_id': grant.customerId,
            'device_id': grant.deviceId,
            'allowed': grant.allowedCreditCentavos,
            'used': grant.usedCreditCentavos,
            'expires_at': grant.expiresAt.toUtc().toIso8601String(),
            'authoritative': serverIssued ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<CreditAllowanceGrant?> getCreditGrant(
      String customerId, String deviceId) async {
    final rows = await _db.query('credit_grants',
        where: 'customer_id=? AND device_id=? AND authoritative=1',
        whereArgs: [customerId, deviceId],
        orderBy: 'rowid DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return CreditAllowanceGrant(
      id: rows.single['id'] as String,
      customerId: rows.single['customer_id'] as String,
      deviceId: rows.single['device_id'] as String,
      allowedCreditCentavos: rows.single['allowed'] as int,
      usedCreditCentavos: rows.single['used'] as int,
      expiresAt: DateTime.parse(rows.single['expires_at'] as String),
    );
  }

  Future<void> recordDebtRepayment(DebtRepayment repayment,
          {CheckoutScope? scope}) =>
      _db.transaction((tx) async {
        final existing = await tx
            .query('debt_repayments', where: 'id=?', whereArgs: [repayment.id]);
        if (existing.isNotEmpty) {
          final old = existing.single;
          if (old['customer_id'] != repayment.customerId ||
              old['amount'] != repayment.amountCentavos ||
              old['tender_kind'] != repayment.tenderKind) {
            throw StateError('Repayment ID changed');
          }
          return;
        }
        final customers = await tx.query('customers',
            where: 'id=?', whereArgs: [repayment.customerId]);
        final shift = await _shift(tx, repayment.shiftId);
        if (customers.isEmpty ||
            shift == null ||
            shift.closed ||
            shift.scope.cashierId != repayment.cashierId ||
            repayment.amountCentavos > (customers.single['balance'] as int)) {
          throw StateError('Check repayment amount and open shift');
        }
        final intent = CheckoutIntent(
            id: repayment.id,
            scope: scope ?? shift.scope,
            shiftId: shift.id,
            ordinal: shift.lastOrdinal + 1,
            occurredAt: repayment.occurredAt,
            kind: 'debtRepayment',
            payload: {
              'customerId': repayment.customerId,
              'amountCentavos': repayment.amountCentavos,
              'tenderKind': repayment.tenderKind,
              'reference': repayment.reference,
              'notes': repayment.notes
            });
        final next = shift.apply(intent);
        await _event(tx, intent);
        await _putShift(tx, next);
        await tx.insert('cash_entries', {
          'id': repayment.id,
          'shift': shift.id,
          'delta': repayment.tenderKind == 'cash' ? repayment.amountCentavos : 0
        });
        await tx.update(
            'customers',
            {
              'balance': (customers.single['balance'] as int) -
                  repayment.amountCentavos
            },
            where: 'id=?',
            whereArgs: [repayment.customerId]);
        await tx.insert('debt_repayments', {
          'id': repayment.id,
          'customer_id': repayment.customerId,
          'amount': repayment.amountCentavos,
          'tender_kind': repayment.tenderKind,
          'shift': repayment.shiftId,
          'cashier': repayment.cashierId,
          'reference': repayment.reference,
          'notes': repayment.notes,
          'occurred_at': repayment.occurredAt.toUtc().toIso8601String()
        });
      });

  Future<List<DebtRepayment>> getDebtRepayments(String customerId) async {
    final rows = await _db.query('debt_repayments',
        where: 'customer_id=?',
        whereArgs: [customerId],
        orderBy: 'occurred_at DESC');
    return rows
        .map((r) => DebtRepayment(
              id: r['id'] as String,
              customerId: r['customer_id'] as String,
              amountCentavos: r['amount'] as int,
              tenderKind: r['tender_kind'] as String,
              occurredAt: DateTime.parse(r['occurred_at'] as String),
              shiftId: r['shift'] as String,
              cashierId: r['cashier'] as String,
              reference: r['reference'] as String,
              notes: r['notes'] as String,
            ))
        .toList();
  }

  static String _businessDate(DateTime date) => date
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 10);
  static int _saleTotal(Map<String, dynamic> payload) =>
      (payload['lines'] as List).fold<int>(0, (n, raw) {
        final line = raw as Map;
        return n + (line['quantity'] as int) * (line['priceCentavos'] as int);
      });

  Future<DailySalesSummary> generateDailySalesSummary({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final datePrefix = _businessDate(targetDate);

    final eventRows = await _db.query('checkout_events');
    int gross = 0;
    int discounts = 0;
    int refunds = 0;
    int cashRefunds = 0, cashVoids = 0;
    int voids = 0;
    int count = 0;
    int cashSales = 0;
    int qrSales = 0;
    int creditSales = 0;
    int otherSales = 0;
    int cashIn = 0;
    int cashOut = 0;

    for (final row in eventRows) {
      final body = jsonDecode(row['body'] as String) as Map<String, dynamic>;
      final occurredAt = DateTime.parse(body['occurredAt'] as String);
      if (_businessDate(occurredAt) != datePrefix) continue;

      final kind = row['kind'] as String;
      if (kind == 'sale') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        final total = _saleTotal(payload);
        final disc = (payload['discountCentavos'] as num?)?.toInt() ?? 0;
        gross += total + disc;
        discounts += disc;
        count++;

        final tender = payload['tender'] as Map<String, dynamic>? ?? {};
        final tKind = tender['kind'] as String? ?? '';
        final tAmount = total;
        if (tKind == 'cash') {
          cashSales += tAmount;
        } else if (tKind.contains('qr') || tKind.contains('Qr')) {
          qrSales += tAmount;
        } else if (tKind == 'credit') {
          creditSales += tAmount;
        } else {
          otherSales += tAmount;
        }
      } else if (kind == 'refund') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        final amount = (payload['lines'] as List)
            .fold<int>(0, (n, l) => n + (l as Map)['refundCentavos'] as int);
        refunds += amount;
        if (payload['tenderKind'] == 'cash') {
          cashRefunds += amount;
        }
      } else if (kind == 'voidSale') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        final amount = (payload['voidCentavos'] as num?)?.toInt() ?? 0;
        voids += amount;
        if (payload['tenderKind'] == 'cash') {
          cashVoids += amount;
        }
      } else if (kind == 'debtRepayment') {
        final payload = body['payload'] as Map<String, dynamic>;
        if (payload['tenderKind'] == 'cash') {
          cashIn += payload['amountCentavos'] as int;
        }
      } else if (kind == 'cashIn') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        cashIn += (payload['amountCentavos'] as num?)?.toInt() ?? 0;
      } else if (kind == 'cashOut') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        cashOut += (payload['amountCentavos'] as num?)?.toInt() ?? 0;
      }
    }

    final shiftRows = await _db.query('checkout_shifts');
    int openingFloat = 0;
    int? countedCash;
    final openedToday = <String>{};
    final closedToday = <String>{};
    for (final event in eventRows) {
      final body = _body(event['body']);
      if (_businessDate(DateTime.parse(body['occurredAt'] as String)) !=
          datePrefix) {
        continue;
      }
      if (event['kind'] == 'openShift') {
        openedToday.add(event['shift'] as String);
      }
      if (event['kind'] == 'closeShift') {
        closedToday.add(event['shift'] as String);
      }
    }

    for (final row in shiftRows) {
      final body = jsonDecode(row['body'] as String) as Map<String, dynamic>;
      final shift = CashierShift.fromMap(body);
      if (openedToday.contains(shift.id)) {
        openingFloat += shift.openingFloatCentavos;
      }
      if (closedToday.contains(shift.id) && shift.countedCentavos != null) {
        countedCash = (countedCash ?? 0) + shift.countedCentavos!;
      }
    }

    return DailySalesSummary(
      date: datePrefix,
      branchId: _inventory.branchId,
      grossSalesCentavos: gross,
      discountsCentavos: discounts,
      refundsCentavos: refunds,
      voidsCentavos: voids,
      cashRefundsCentavos: cashRefunds,
      cashVoidsCentavos: cashVoids,
      transactionCount: count,
      tenders: TenderBreakdown(
        cashCentavos: cashSales,
        qrCentavos: qrSales,
        creditCentavos: creditSales,
        otherCentavos: otherSales,
      ),
      cashInCentavos: cashIn,
      cashOutCentavos: cashOut,
      openingFloatCentavos: openingFloat,
      actualCountedCashCentavos: countedCash,
    );
  }

  Future<ZReading> generateZReading(String shiftId) async {
    final shiftRows =
        await _db.query('checkout_shifts', where: 'id=?', whereArgs: [shiftId]);
    if (shiftRows.isEmpty) throw StateError('Shift not found: $shiftId');
    final shift = CashierShift.fromMap(
        _body(jsonDecode(shiftRows.single['body'] as String)));

    final eventRows = await _db
        .query('checkout_events', where: 'shift=?', whereArgs: [shiftId]);
    int gross = 0;
    int discounts = 0;
    int refunds = 0;
    int voids = 0;
    int count = 0;
    int cashSales = 0;
    int qrSales = 0;
    int creditSales = 0;
    int otherSales = 0;
    int cashIn = 0;
    int cashOut = 0;
    DateTime? firstEvent, lastEvent;

    for (final row in eventRows) {
      final body = jsonDecode(row['body'] as String) as Map<String, dynamic>;
      final occurredAt =
          DateTime.tryParse(body['occurredAt'] as String? ?? '') ??
              DateTime.now();
      if (firstEvent == null || firstEvent.isAfter(occurredAt)) {
        firstEvent = occurredAt;
      }
      if (lastEvent == null || lastEvent.isBefore(occurredAt)) {
        lastEvent = occurredAt;
      }

      final kind = row['kind'] as String;
      if (kind == 'sale') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        final total = _saleTotal(payload);
        final disc = (payload['discountCentavos'] as num?)?.toInt() ?? 0;
        gross += total + disc;
        discounts += disc;
        count++;

        final tender = payload['tender'] as Map<String, dynamic>? ?? {};
        final tKind = tender['kind'] as String? ?? '';
        final tAmount = total;
        if (tKind == 'cash') {
          cashSales += tAmount;
        } else if (tKind.contains('qr') || tKind.contains('Qr')) {
          qrSales += tAmount;
        } else if (tKind == 'credit') {
          creditSales += tAmount;
        } else {
          otherSales += tAmount;
        }
      } else if (kind == 'refund') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        refunds += (payload['lines'] as List)
            .fold<int>(0, (n, l) => n + (l as Map)['refundCentavos'] as int);
      } else if (kind == 'voidSale') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        voids += (payload['voidCentavos'] as num?)?.toInt() ?? 0;
      } else if (kind == 'debtRepayment') {
        final payload = body['payload'] as Map<String, dynamic>;
        if (payload['tenderKind'] == 'cash') {
          cashIn += payload['amountCentavos'] as int;
        }
      } else if (kind == 'cashIn') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        cashIn += (payload['amountCentavos'] as num?)?.toInt() ?? 0;
      } else if (kind == 'cashOut') {
        final payload = body['payload'] as Map<String, dynamic>? ?? {};
        cashOut += (payload['amountCentavos'] as num?)?.toInt() ?? 0;
      }
    }

    final netSales = gross - discounts - refunds - voids;
    final expectedCash = shift.expectedCashCentavos;
    final countedCash = shift.countedCentavos ?? expectedCash;
    final variance = countedCash - expectedCash;

    return ZReading(
      id: 'z-$shiftId',
      readingNumber: shift.lastOrdinal,
      shiftId: shiftId,
      branchId: shift.scope.branchId,
      deviceId: shift.scope.deviceId,
      cashierId: shift.scope.cashierId,
      cashierName: shift.scope.cashierId,
      openedAt: firstEvent ?? DateTime.now(),
      closedAt: lastEvent ?? DateTime.now(),
      openingFloatCentavos: shift.openingFloatCentavos,
      grossSalesCentavos: gross,
      netSalesCentavos: netSales,
      refundsCentavos: refunds,
      voidsCentavos: voids,
      tenders: TenderBreakdown(
        cashCentavos: cashSales,
        qrCentavos: qrSales,
        creditCentavos: creditSales,
        otherCentavos: otherSales,
      ),
      cashInCentavos: cashIn,
      cashOutCentavos: cashOut,
      expectedCashCentavos: expectedCash,
      countedCashCentavos: countedCash,
      varianceCentavos: variance,
      cashierNotes: shift.reason,
      transactionCount: count,
    );
  }
}
