import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'checkout_store_test.dart' as f;

class Gateway implements CheckoutGateway {
  final sent = <CheckoutIntent>[];
  int? failAt;
  bool blocked = false;
  @override
  Future<CheckoutAck> push(CheckoutIntent i, IssuedCashierGrant g) async {
    if (sent.length == failAt) throw StateError('Network timeout');
    sent.add(i);
    return CheckoutAck(i.id, blocked ? 'blocked' : 'accepted',
        sequence: i.kind == 'sale' ? 1 : null);
  }

  @override
  Future<List<CatalogChange>> resolveQuotes(
          String m, String b, List<CatalogProduct> p) async =>
      [];
}

void main() {
  sqfliteFfiInit();
  late InventoryStore store;
  late Directory dir;
  final grant = IssuedCashierGrant(
      scope: f.scope,
      secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      issuedAt: f.now,
      expiresAt: f.now.add(const Duration(days: 7)));
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('checkout-sync');
    store = await InventoryStore.open(databaseFactoryFfi, '${dir.path}/db',
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
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  StockEvent event({String id = 'sale', int delta = -1, int seq = 1}) =>
      StockEvent(
          sequence: seq,
          operationId: id,
          kind: 'sale',
          positions: [StockPosition('p', 8, 1, delta: delta)]);
  test('ACK then feed and feed then ACK settle without double subtraction',
      () async {
    await store.checkout
        .acknowledge(const CheckoutAck('sale', 'accepted', sequence: 1));
    expect((await store.search('')).single.quantity, -1);
    await store
        .applyStock(DeltaPage(cursor: 1, hasMore: false, changes: [event()]));
    expect((await store.search('')).single.quantity, 8);
    await store.checkout
        .acknowledge(const CheckoutAck('sale', 'duplicate', sequence: 1));
    expect((await store.search('')).single.quantity, 8);
  });
  test(
      'lost ACK is settled by matching event, foreign consumed event cannot settle',
      () async {
    await store.applyStock(
        DeltaPage(cursor: 1, hasMore: false, changes: [event(id: 'another')]));
    expect((await store.search('')).single.quantity, 7);
    await expectLater(
        store.checkout
            .acknowledge(const CheckoutAck('sale', 'accepted', sequence: 1)),
        throwsFormatException);
    await store.applyStock(
        DeltaPage(cursor: 2, hasMore: false, changes: [event(seq: 2)]));
    await store.checkout
        .acknowledge(const CheckoutAck('sale', 'duplicate', sequence: 2));
    expect((await store.search('')).single.quantity, 8);
  });
  test('wrong delta or gaps roll back the whole event and cursor', () async {
    await expectLater(
        store.applyStock(
            DeltaPage(cursor: 1, hasMore: false, changes: [event(delta: -2)])),
        throwsFormatException);
    expect(await store.stockCursor(), 0);
    expect((await store.search('')).single.quantity, -1);
    await expectLater(
        store.applyStock(
            DeltaPage(cursor: 2, hasMore: false, changes: [event(seq: 2)])),
        throwsFormatException);
    expect(await store.stockCursor(), 0);
  });
  test('multi-product mismatch rolls back every stock position and ACK',
      () async {
    final q = CatalogProduct(
        id: 'q',
        sku: 'Q',
        name: 'Rice',
        baseUnit: 'piece',
        revision: 1,
        active: true,
        units: [CatalogUnit(name: 'piece', factor: 1, priceCentavos: 100)]);
    await store.applyCatalog(
        DeltaPage(cursor: 2, hasMore: false, changes: [CatalogChange(2, q)]));
    final lines = [
      ...f.sale().lines,
      CartLine(
          productId: 'q',
          sku: 'Q',
          name: 'Rice',
          unit: 'piece',
          factor: 1,
          priceCentavos: 100,
          quantity: 1,
          catalogSequence: 2,
          catalogRevision: 1)
    ];
    final receipt = CheckoutSale(
        id: 'multi',
        scope: f.scope,
        shiftId: 'shift',
        ordinal: 3,
        occurredAt: f.now,
        merchantName: 'Store',
        branchName: 'Main',
        lines: lines,
        tender: const Tender.cash(2000));
    await store.checkout.saveDraft(CheckoutDraft(
        scope: f.scope, shiftId: 'shift', lines: lines, frozenSale: receipt));
    await store.checkout.completeSale(receipt);
    final bad = StockEvent(
        sequence: 1,
        operationId: 'multi',
        kind: 'sale',
        positions: [
          StockPosition('p', 50, 1, delta: -1),
          StockPosition('q', 50, 1, delta: -2)
        ]);
    await expectLater(
        store.applyStock(DeltaPage(cursor: 1, hasMore: false, changes: [bad])),
        throwsFormatException);
    expect(await store.stockCursor(), 0);
    expect((await store.search('Milk')).single.quantity, -2);
    expect((await store.search('Rice')).single.quantity, -1);
    expect((await store.checkout.pendingIntents()).map((i) => i.id),
        ['shift', 'sale', 'multi']);
  });
  test('foreign or changed acknowledgements cannot settle receipt', () async {
    await expectLater(
        store.checkout
            .acknowledge(const CheckoutAck('foreign', 'accepted', sequence: 1)),
        throwsFormatException);
    await expectLater(
        store.checkout.acknowledge(const CheckoutAck('sale', 'accepted')),
        throwsFormatException);
    await store.checkout
        .acknowledge(const CheckoutAck('sale', 'accepted', sequence: 1));
    await expectLater(
        store.checkout
            .acknowledge(const CheckoutAck('sale', 'duplicate', sequence: 2)),
        throwsFormatException);
    await expectLater(
        store.applyStock(DeltaPage(
            cursor: 2,
            hasMore: false,
            changes: [event(id: 'other'), event(seq: 2)])),
        throwsFormatException);
    expect(await store.stockCursor(), 0);
    expect((await store.search('')).single.quantity, -1);
  });
  test(
      'partial upload immediately saves ACK and timeout retains remaining work',
      () async {
    final gateway = Gateway()..failAt = 1;
    final sync = CheckoutSync(store.checkout, gateway,
        grantResolver: (s) async => grant);
    await expectLater(sync.run(), throwsStateError);
    expect((await store.checkout.pendingIntents()).map((i) => i.id), ['sale']);
    gateway.failAt = null;
    await sync.run();
    expect(gateway.sent.map((i) => i.id), ['shift', 'sale']);
  });
  test('blocked dependency stops close; missing grant retains all business',
      () async {
    await store.checkout.closeShift(CheckoutIntent(
        id: 'close',
        scope: f.scope,
        shiftId: 'shift',
        ordinal: 3,
        occurredAt: f.now,
        kind: 'closeShift',
        payload: {'countedCentavos': 6250, 'reason': ''}));
    final gateway = Gateway();
    expect(
        await CheckoutSync(store.checkout, gateway,
            grantResolver: (s) async => null).run(),
        true);
    expect(gateway.sent, isEmpty);
    gateway.blocked = true;
    await CheckoutSync(store.checkout, gateway,
        grantResolver: (s) async => grant).run();
    expect(gateway.sent.map((i) => i.id), ['shift']);
    expect(await store.checkout.pendingIntents(), hasLength(3));
    expect(await store.checkout.sale('sale'), isNotNull);
  });
  test('one action uploads at most twenty intents in durable order', () async {
    for (var n = 3; n <= 24; n++) {
      await store.checkout.recordCashMovement(CheckoutIntent(
          id: 'cash$n',
          scope: f.scope,
          shiftId: 'shift',
          ordinal: n,
          occurredAt: f.now,
          kind: 'cashIn',
          payload: {'amountCentavos': 1, 'reason': 'Float'}));
    }
    final gateway = Gateway();
    expect(
        await CheckoutSync(store.checkout, gateway,
            grantResolver: (s) async => grant).run(),
        true);
    expect(gateway.sent, hasLength(20));
    expect(gateway.sent.last.ordinal, 20);
    expect(await store.checkout.pendingIntents(), hasLength(4));
  });
}
