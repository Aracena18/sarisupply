import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final scope = CheckoutScope(
    merchantId: 'm',
    branchId: 'b',
    deviceId: 'd',
    cashierId: 'c',
    grantId: 'g',
    credentialVersion: 1);
final now = DateTime.utc(2026, 10, 5);
final product = CatalogProduct(
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
CheckoutIntent opening() => CheckoutIntent(
    id: 'shift',
    scope: scope,
    shiftId: 'shift',
    ordinal: 1,
    occurredAt: now,
    kind: 'openShift',
    payload: {'floatCentavos': 5000});
CheckoutSale sale(
        {String id = 'sale',
        int received = 2000,
        int ordinal = 2,
        Tender? tender}) =>
    CheckoutSale(
        id: id,
        scope: scope,
        shiftId: 'shift',
        ordinal: ordinal,
        occurredAt: now,
        merchantName: 'Store',
        branchName: 'Main',
        lines: [
          CartLine(
              productId: 'p',
              sku: 'MILK',
              name: 'Milk',
              unit: 'piece',
              factor: 1,
              priceCentavos: 1250,
              quantity: 1,
              catalogSequence: 1,
              catalogRevision: 1)
        ],
        tender: tender ?? Tender.cash(received));
void main() {
  sqfliteFfiInit();
  late Directory dir;
  late InventoryStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('checkout-');
    store = await InventoryStore.open(databaseFactoryFfi, '${dir.path}/db',
        merchantId: 'm', branchId: 'b');
    await store.applyCatalog(DeltaPage(
        cursor: 1, hasMore: false, changes: [CatalogChange(1, product)]));
    await store.checkout.openShift(opening());
    await store.checkout.saveDraft(CheckoutDraft(
        scope: scope,
        shiftId: 'shift',
        lines: sale().lines,
        frozenSale: sale()));
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  test(
      'refund and void reject changed receipt terms without local side effects',
      () async {
    await store.checkout.completeSale(sale());
    RefundIntent refund(String id,
            {int factor = 1,
            int price = 1250,
            String tender = 'cash',
            int duplicates = 1}) =>
        RefundIntent(
            id: id,
            originalSaleId: 'sale',
            scope: scope,
            shiftId: 'shift',
            ordinal: 3,
            occurredAt: now,
            lines: List.generate(
                duplicates,
                (_) => RefundLine(
                    productId: 'p',
                    sku: 'MILK',
                    name: 'Milk',
                    unit: 'piece',
                    factor: factor,
                    priceCentavos: price,
                    quantity: 1,
                    refundCentavos: 500)),
            tenderKind: tender,
            reason: 'Return',
            authorizedByCashierId: 'c');
    for (final invalid in [
      refund('factor', factor: 2),
      refund('price', price: 1500),
      refund('tender', tender: 'qr'),
      refund('repeated', duplicates: 2)
    ]) {
      await expectLater(
          store.checkout.recordRefund(invalid), throwsArgumentError);
      expect(await store.checkout.operation(invalid.id), isNull);
    }
    for (final invalid in [
      VoidIntent(
          id: 'wrongTotal',
          originalSaleId: 'sale',
          scope: scope,
          shiftId: 'shift',
          ordinal: 3,
          occurredAt: now,
          reason: 'Cancel',
          authorizedByCashierId: 'c',
          voidCentavos: 500),
      VoidIntent(
          id: 'wrongTender',
          originalSaleId: 'sale',
          scope: scope,
          shiftId: 'shift',
          ordinal: 3,
          occurredAt: now,
          reason: 'Cancel',
          authorizedByCashierId: 'c',
          voidCentavos: 1250,
          tenderKind: 'qr')
    ]) {
      await expectLater(store.checkout.voidSale(invalid), throwsArgumentError);
      expect(await store.checkout.operation(invalid.id), isNull);
    }
    expect((await store.checkout.activeShift('d'))!.lastOrdinal, 2);
    expect((await store.checkout.activeShift('d'))!.expectedCashCentavos, 6250);
    expect((await store.getProduct('p'))!.quantity, -1);
  });
  test(
      'Owner review retries only missing-approval reversals and retains the same intent',
      () async {
    await store.checkout.completeSale(sale());
    final refund = RefundIntent(
        id: 'review',
        originalSaleId: 'sale',
        scope: scope,
        shiftId: 'shift',
        ordinal: 3,
        occurredAt: now,
        lines: [
          RefundLine(
              productId: 'p',
              sku: 'MILK',
              name: 'Milk',
              unit: 'piece',
              factor: 1,
              priceCentavos: 1250,
              quantity: 1,
              refundCentavos: 1250)
        ],
        tenderKind: 'cash',
        reason: 'Return',
        authorizedByCashierId: 'c');
    await store.checkout.recordRefund(refund);
    await store.checkout.acknowledge(CheckoutAck('review', 'blocked',
        message: 'Owner approval required for this exact refund or void'));
    await store.checkout.retryOwnerApprovedReversal('review');
    expect((await store.checkout.operation('review'))!.status, 'pending');
    expect((await store.checkout.operation('review'))!.toMap(),
        refund.toCheckoutIntent().toMap());
    await store.checkout.acknowledge(CheckoutAck('review', 'blocked',
        message: 'Refund or void needs review'));
    await expectLater(
        store.checkout.retryOwnerApprovedReversal('review'), throwsStateError);
    expect((await store.checkout.operation('review'))!.status, 'blocked');
  });
  test(
      'sale is durable, negative stock allowed, exact replay returns one receipt',
      () async {
    await store.checkout.completeSale(sale());
    await store.checkout.completeSale(sale());
    expect((await store.search('')).single.quantity, -1);
    expect((await store.checkout.activeShift('d'))!.expectedCashCentavos, 6250);
    expect(await store.checkout.receipts(), hasLength(1));
    await store.close();
    store = await InventoryStore.open(databaseFactoryFfi, '${dir.path}/db',
        merchantId: 'm', branchId: 'b');
    expect((await store.checkout.sale('sale'))!.changeCentavos, 750);
    expect(await store.checkout.readDraft('d', 'c'), isNull);
    expect(await store.checkout.pendingIntents(), hasLength(2));
    await expectLater(
        store.checkout.completeSale(sale(received: 3000)), throwsStateError);
  });
  test(
      'reservation attempt survives reopen and cannot be edited or discarded before cancellation',
      () async {
    await store.checkout.completeSale(sale());
    final locked = CheckoutDraft(
        scope: scope,
        shiftId: 'shift',
        lines: sale().lines,
        tenderKind: 'credit',
        qrReference: 'customer',
        paymentAttemptId: 'attempt');
    await store.checkout.saveDraft(locked);
    await store.close();
    store = await InventoryStore.open(databaseFactoryFfi, '${dir.path}/db',
        merchantId: 'm', branchId: 'b');
    expect((await store.checkout.readDraft('d', 'c'))!.paymentAttemptId,
        'attempt');
    await expectLater(
        store.checkout.saveDraft(locked.copyWith(qrReference: 'other')),
        throwsStateError);
    await expectLater(store.checkout.discardDraft('d', 'c'), throwsStateError);
    await store.checkout.cancelReservedDraft('d', 'c', 'attempt');
    await store.checkout.discardDraft('d', 'c');
    expect(await store.checkout.readDraft('d', 'c'), isNull);
  });

  for (final table in [
    'checkout_sales',
    'checkout_tenders',
    'sale_stock',
    'cash_entries',
    'checkout_outbox',
    'checkout_recovery'
  ]) {
    test(
        'failure in $table rolls back the whole sale and preserves frozen draft',
        () async {
      final db = await databaseFactoryFfi.openDatabase('${dir.path}/db',
          options: OpenDatabaseOptions(singleInstance: false));
      await db.execute(
          "CREATE TRIGGER fail_sale BEFORE INSERT ON $table BEGIN SELECT RAISE(ABORT,'disk failure'); END");
      await expectLater(store.checkout.completeSale(sale()), throwsA(anything));
      expect(await store.checkout.sale('sale'), isNull);
      expect((await store.search('')).single.quantity, 0);
      expect(
          (await store.checkout.activeShift('d'))!.expectedCashCentavos, 5000);
      expect(
          (await store.checkout.readDraft('d', 'c'))!.frozenSale!.id, 'sale');
      expect(await store.checkout.pendingIntents(), hasLength(1));
      await db.execute('DROP TRIGGER fail_sale');
      await db.close();
      await store.checkout.completeSale(sale());
      expect(await store.checkout.receipts(), hasLength(1));
    });
  }
  test('draft completion failure also rolls back sale', () async {
    final db = await databaseFactoryFfi.openDatabase('${dir.path}/db',
        options: OpenDatabaseOptions(singleInstance: false));
    await db.execute(
        "CREATE TRIGGER fail_draft BEFORE DELETE ON checkout_drafts BEGIN SELECT RAISE(ABORT,'disk failure'); END");
    await expectLater(store.checkout.completeSale(sale()), throwsA(anything));
    expect(await store.checkout.sale('sale'), isNull);
    expect(await store.checkout.readDraft('d', 'c'), isNotNull);
    await db.close();
  });
  test('QR leaves expected cash unchanged and close records discrepancy',
      () async {
    await store.checkout.completeSale(sale());
    final qr = sale(
        id: 'qr', ordinal: 3, tender: Tender.qr('bank-ref', confirmed: true));
    await store.checkout.saveDraft(CheckoutDraft(
        scope: scope, shiftId: 'shift', lines: qr.lines, frozenSale: qr));
    await store.checkout.completeSale(qr);
    expect((await store.checkout.activeShift('d'))!.expectedCashCentavos, 6250);
    await store.checkout.closeShift(CheckoutIntent(
        id: 'close',
        scope: scope,
        shiftId: 'shift',
        ordinal: 4,
        occurredAt: now,
        kind: 'closeShift',
        payload: {'countedCentavos': 6150, 'reason': 'Short cash'}));
    expect(await store.checkout.activeShift('d'), isNull);
    await expectLater(
        store.checkout.recordCashMovement(CheckoutIntent(
            id: 'late',
            scope: scope,
            shiftId: 'shift',
            ordinal: 5,
            occurredAt: now,
            kind: 'cashIn',
            payload: {'amountCentavos': 1, 'reason': 'Late'})),
        throwsStateError);
  });
  test('count before sale remains baseline until count settles', () async {
    await store.recordCount(
        id: 'count',
        productId: 'p',
        quantity: 10,
        kind: 'opening',
        reason: 'Opening');
    await store.checkout.completeSale(sale());
    expect((await store.search('')).single.quantity, 9);
    await expectLater(
        store.recordCount(
            id: 'later',
            productId: 'p',
            quantity: 9,
            kind: 'count',
            reason: 'Count'),
        throwsStateError);
  });
  test('catalog update after payment freeze cannot strand a collected tender',
      () async {
    final changed = CatalogProduct(
        id: 'p',
        sku: 'MILK',
        name: 'Milk',
        baseUnit: 'piece',
        revision: 2,
        active: true,
        units: [CatalogUnit(name: 'piece', factor: 1, priceCentavos: 1300)]);
    await store.applyCatalog(DeltaPage(
        cursor: 2, hasMore: false, changes: [CatalogChange(2, changed)]));
    await store.checkout.completeSale(sale());
    expect((await store.checkout.sale('sale'))!.totalCentavos, 1250);
  });
  test('one shift per device and cashier binding survive reopen', () async {
    await expectLater(
        store.checkout.openShift(CheckoutIntent(
            id: 'second',
            scope: scope,
            shiftId: 'second',
            ordinal: 1,
            occurredAt: now,
            kind: 'openShift',
            payload: {'floatCentavos': 0})),
        throwsStateError);
    final foreign = CheckoutScope(
        merchantId: 'm',
        branchId: 'b',
        deviceId: 'd',
        cashierId: 'other',
        grantId: 'g2',
        credentialVersion: 1);
    await expectLater(
        store.checkout.recordCashMovement(CheckoutIntent(
            id: 'foreign',
            scope: foreign,
            shiftId: 'shift',
            ordinal: 2,
            occurredAt: now,
            kind: 'cashIn',
            payload: {'amountCentavos': 1, 'reason': 'Float'})),
        throwsStateError);
    await store.close();
    store = await InventoryStore.open(databaseFactoryFfi, '${dir.path}/db',
        merchantId: 'm', branchId: 'b');
    expect((await store.checkout.readDraft('d', 'c'))!.frozenSale!.id, 'sale');
    expect(await store.checkout.readDraft('d', 'other'), isNull);
    await expectLater(
        store.checkout.closeShift(CheckoutIntent(
            id: 'missing-reason',
            scope: scope,
            shiftId: 'shift',
            ordinal: 2,
            occurredAt: now,
            kind: 'closeShift',
            payload: {'countedCentavos': 4900, 'reason': ''})),
        throwsArgumentError);
    expect(await store.checkout.pendingIntents(), hasLength(1));
  });
  test('receipt presentation recovery is durable and isolated by cashier',
      () async {
    await store.checkout.completeSale(sale());
    await store.close();
    store = await InventoryStore.open(databaseFactoryFfi, '${dir.path}/db',
        merchantId: 'm', branchId: 'b');
    expect((await store.checkout.unseenReceipt('d', 'c'))!.id, 'sale');
    expect(await store.checkout.unseenReceipt('d', 'other'), isNull);
    await store.checkout.markReceiptSeen('d', 'c', 'sale');
    expect(await store.checkout.unseenReceipt('d', 'c'), isNull);
    expect(await store.checkout.receipts(), hasLength(1));
  });
  test('immutable finance cannot be edited or deleted', () async {
    await store.checkout.completeSale(sale());
    final db = await databaseFactoryFfi.openDatabase('${dir.path}/db',
        options: OpenDatabaseOptions(singleInstance: false));
    for (final table in [
      'checkout_events',
      'checkout_sales',
      'checkout_tenders',
      'sale_stock',
      'cash_entries'
    ]) {
      await expectLater(db.delete(table), throwsA(anything));
    }
    await expectLater(
        db.update('checkout_sales', {'body': '{}'}), throwsA(anything));
    await db.close();
  });
}
