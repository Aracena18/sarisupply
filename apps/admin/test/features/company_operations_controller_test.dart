import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/sarisupply_company.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

CompanyPage page(String id, {String? cursor}) => CompanyPage(records: [
      CompanyRecord({'id': id})
    ], nextCursor: cursor, hasMore: cursor != null);

void main() {
  test('20 warm visits reuse pages without network reads; freshness expires',
      () async {
    var now = DateTime(2026, 10, 6);
    var calls = 0;
    final c = CompanyOperationsController(
        scope: 'user/company/role/revisions',
        now: () => now,
        read: (kind, warehouse, cursor) async {
          calls++;
          return page(kind);
        });
    addTearDown(c.dispose);
    await c.load('orders', warehouseId: 'w');
    await c.load('warehouses');
    for (var i = 0; i < 20; i++) {
      await c.load('orders', warehouseId: 'w');
      await c.load('warehouses');
    }
    expect(calls, 2);
    now = now.add(const Duration(seconds: 31));
    await c.load('orders', warehouseId: 'w');
    await c.load('warehouses');
    expect(calls, 3);
  });

  test('coalesces reads and limits independent requests to three', () async {
    final gates = <Completer<CompanyPage>>[];
    var active = 0, peak = 0;
    final c = CompanyOperationsController(
        scope: 's',
        read: (kind, w, cursor) async {
          active++;
          if (active > peak) peak = active;
          final gate = Completer<CompanyPage>();
          gates.add(gate);
          try {
            return await gate.future;
          } finally {
            active--;
          }
        });
    addTearDown(c.dispose);
    final a = c.load('products');
    final same = c.load('products');
    expect(identical(a, same), isTrue);
    final b = c.load('orders'), d = c.load('runs'), e = c.load('warehouses');
    await Future<void>.delayed(Duration.zero);
    expect(gates, hasLength(3));
    for (final gate in gates.toList()) {
      gate.complete(page('first'));
    }
    await Future<void>.delayed(Duration.zero);
    expect(gates, hasLength(4));
    gates.last.complete(page('last'));
    await Future.wait([a, same, b, d, e]);
    expect(peak, 3);
  });

  test('invalidated late response cannot replace a newer mutation refresh',
      () async {
    final gates = <Completer<CompanyPage>>[];
    final c = CompanyOperationsController(
        scope: 's',
        read: (_, w, cursor) {
          final gate = Completer<CompanyPage>();
          gates.add(gate);
          return gate.future;
        });
    addTearDown(c.dispose);
    final old = c.load('orders');
    await Future<void>.delayed(Duration.zero);
    c.invalidate('orders');
    final fresh = c.load('orders');
    await Future<void>.delayed(Duration.zero);
    gates.last.complete(page('new'));
    await fresh;
    gates.first.complete(page('old'));
    await old;
    expect(c.dataset('orders').records.single.id, 'new');
  });

  test('refresh preserves rows, loaded pages, and deduplicates records',
      () async {
    var calls = 0;
    final c = CompanyOperationsController(
        scope: 's',
        read: (_, w, cursor) async {
          calls++;
          return cursor == null ? page('a', cursor: 'a') : page('b');
        });
    addTearDown(c.dispose);
    await c.load('products', warehouseId: 'w');
    await c.more('products', warehouseId: 'w');
    await c.load('products', warehouseId: 'w', force: true);
    expect(calls, 4);
    expect(c.dataset('products', warehouseId: 'w').records.map((r) => r.id),
        ['a', 'b']);
  });

  test('failed pagination can retry a refresh inside the freshness window',
      () async {
    var calls = 0;
    final c = CompanyOperationsController(
        scope: 's',
        read: (_, warehouse, cursor) async {
          calls++;
          if (cursor != null) throw StateError('offline');
          return page('a', cursor: 'a');
        });
    addTearDown(c.dispose);
    await c.load('products');
    await expectLater(c.more('products'), throwsStateError);
    expect(c.dataset('products').records.single.id, 'a');
    await c.load('products');
    expect(calls, 3);
    expect(c.dataset('products').error, isNull);
  });

  test('disk seed is stale display data; failed refresh retains it', () async {
    final c = CompanyOperationsController(
        scope: 's',
        read: (_, w, cursor) async {
          throw StateError('offline');
        });
    addTearDown(c.dispose);
    c.seed('runs', page('pending-run').records);
    expect(c.dataset('runs').fetchedAt, isNull);
    await expectLater(c.load('runs'), throwsStateError);
    expect(c.dataset('runs').records.single.id, 'pending-run');
    expect(c.dataset('runs').refreshing, isFalse);
  });

  test(
      'warehouses and account scopes never share records; clear rejects late data',
      () async {
    final gate = Completer<CompanyPage>();
    final c = CompanyOperationsController(
        scope: 'account-a', read: (_, w, cursor) => gate.future);
    addTearDown(c.dispose);
    c.seed('products', page('a').records, warehouseId: 'a');
    expect(c.dataset('products', warehouseId: 'b').records, isEmpty);
    final work = c.load('products', warehouseId: 'a');
    await Future<void>.delayed(Duration.zero);
    c.clear();
    gate.complete(page('late'));
    await work;
    expect(c.dataset('products', warehouseId: 'a').records, isEmpty);
  });
}
