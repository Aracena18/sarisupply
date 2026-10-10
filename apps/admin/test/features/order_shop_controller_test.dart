import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/order_shop_controller.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

class Memory extends Fake implements CompanyWorkStorage {
  final docs = <String, Map<String, Object?>>{};
  @override
  Future<Map<String, Object?>?> document(String key) async => docs[key];
  @override
  Future<void> saveDocument(String key, Map<String, Object?> body) async {
    docs[key] = body;
  }
}

CompanyRecord p(String id) => CompanyRecord({
      'id': id,
      'name': id,
      'priceCentavos': 100,
      'revision': 1,
      'active': true
    });
CompanyPage page(String id, {String? cursor}) =>
    CompanyPage(records: [p(id)], nextCursor: cursor, hasMore: cursor != null);
void main() {
  test('cart edits and suggestion additions perform zero catalog reads',
      () async {
    var reads = 0;
    final c = OrderCatalogController(
        storage: Memory(),
        read: (w, q, cursor) async {
          reads++;
          return page('p');
        });
    final cart = OrderCartController();
    await c.load('w', '');
    for (var i = 0; i < 50; i++) {
      cart.add(p('p'));
      cart.setQuantity('p', 2);
      cart.setQuantity('p', 0);
    }
    cart.add(p('p'), count: 4);
    cart.add(p('p'), count: 10, preserve: true);
    expect(cart.quantity('p').value, 4);
    expect(cart.total, 400);
    expect(reads, 1);
    cart.dispose();
    c.dispose();
  });
  test(
      'page append and warm reopen reuse cache; stale refresh reads only first page',
      () async {
    var now = DateTime(2026, 10, 7);
    final calls = <String?>[];
    final c = OrderCatalogController(
        storage: Memory(),
        now: () => now,
        read: (w, q, cursor) async {
          calls.add(cursor);
          return cursor == null ? page('a', cursor: 'next') : page('b');
        });
    await c.load('w', '');
    await c.load('w', '', more: true);
    await c.load('w', '');
    expect(calls, [null, 'next']);
    now = now.add(const Duration(seconds: 31));
    await c.load('w', '');
    expect(calls, [null, 'next', null]);
    expect(c.page('w', '').records.map((r) => r.id), ['a', 'b']);
    c.dispose();
  });
  test('coalesces identical reads and keeps search/warehouse results separate',
      () async {
    final gate = Completer<CompanyPage>();
    var reads = 0;
    final c = OrderCatalogController(
        storage: Memory(),
        read: (w, q, cursor) async {
          reads++;
          if (q == 'old') return gate.future;
          return page('$w:$q');
        });
    final old = c.load('w', 'old');
    expect(identical(old, c.load('w', 'old')), true);
    await c.load('w', 'new');
    gate.complete(page('old'));
    await old;
    expect(c.page('w', 'new').records.single.id, 'w:new');
    await c.load('other', 'new');
    expect(reads, 3);
    c.dispose();
  });
  test('access invalidation rejects late catalog responses', () async {
    final gate = Completer<CompanyPage>();
    final c = OrderCatalogController(
        storage: Memory(), read: (w, q, cursor) => gate.future);
    final work = c.load('w', '');
    await Future<void>.delayed(Duration.zero);
    c.clear();
    gate.complete(page('private'));
    await work;
    expect(c.page('w', '').records, isEmpty);
    c.dispose();
  });
  test(
      'draft writes serialize; close flushes final snapshot and prevents resurrection',
      () async {
    final calls = <int>[];
    final gate = Completer<void>();
    final writer = OrderDraftWriter((v) async {
      calls.add(v['value'] as int);
      if (v['value'] == 1) await gate.future;
    });
    writer.schedule({'value': 1});
    final first = writer.flush();
    writer.schedule({'value': 2});
    final close = writer.close();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [1]);
    gate.complete();
    await first;
    await close;
    expect(calls, [1, 2]);
    writer.schedule({'value': 3});
    await writer.flush();
    expect(calls, [1, 2]);
  });
  test('unit conversion rounds up and preserves meaningful low stock defaults',
      () {
    expect(suggestedCompanyQuantity(10, 6), 2);
    expect(suggestedCompanyQuantity(0, 12), 2);
    expect(suggestedCompanyQuantity(-3, 1), 23);
    expect(() => suggestedCompanyQuantity(0, 0), throwsArgumentError);
  });
}
