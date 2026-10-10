import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';

typedef OrderValues = Map<String, Object?>;
typedef OrderCatalogReader =
    Future<CompanyPage> Function(
      String warehouse,
      String query,
      String? cursor,
    );

/// Scoped to the verified workspace. Cart notifications never invoke catalog reads.
final class OrderCatalogController extends ChangeNotifier {
  OrderCatalogController({
    required this.read,
    required this.storage,
    this.cacheScope = '',
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final OrderCatalogReader read;
  final CompanyWorkStorage storage;
  final String cacheScope;
  final DateTime Function() _now;
  final Map<(String, String), OrderCatalogPage> _pages = {};
  bool _closed = false;
  int _generation = 0;
  OrderCatalogPage page(String warehouse, String query) => _pages.putIfAbsent((
    warehouse,
    query.trim().toLowerCase(),
  ), OrderCatalogPage.new);
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> load(
    String warehouse,
    String query, {
    bool more = false,
    bool force = false,
  }) {
    query = query.trim().toLowerCase();
    final state = page(warehouse, query);
    if (_closed) return Future.value();
    if (state.work != null) return state.work!;
    if (more && !state.hasMore) return Future.value();
    if (!more &&
        !force &&
        state.updatedAt != null &&
        _now().difference(state.updatedAt!) < const Duration(seconds: 30)) {
      return Future.value();
    }
    state.loading = true;
    state.error = null;
    final work = _load(warehouse, query, state, more, _generation);
    state.work = work;
    _notify();
    return work;
  }

  Future<void> _load(
    String warehouse,
    String query,
    OrderCatalogPage state,
    bool more,
    int generation,
  ) async {
    final key =
        'catalog:${Uri.encodeComponent(cacheScope)}:${Uri.encodeComponent(warehouse)}:${Uri.encodeComponent(query)}';
    try {
      if (query.isEmpty && state.records.isEmpty && !more) {
        final saved = await storage.document(key);
        if (_closed || generation != _generation) return;
        if (saved != null) {
          state.records = (saved['records'] as List? ?? [])
              .map((v) => CompanyRecord(Map<String, Object?>.from(v as Map)))
              .toList();
          state.cursor = saved['cursor'] as String?;
          state.hasMore = saved['hasMore'] == true;
          state.updatedAt = DateTime.tryParse(
            saved['updatedAt'] as String? ?? '',
          );
          state.cached = true;
          _notify();
        }
      }
      final oldCursor = state.cursor;
      final oldMore = state.hasMore;
      final retainPages = !more && state.appended;
      final result = await read(warehouse, query, more ? state.cursor : null);
      if (_closed || generation != _generation) return;
      final records = {for (final p in state.records) p.id: p};
      if (!more && !retainPages) records.clear();
      for (final p in result.records) {
        records[p.id] = p;
      }
      state.records = List.unmodifiable(records.values);
      state.cursor = retainPages ? oldCursor : result.nextCursor;
      state.hasMore = retainPages ? oldMore : result.hasMore;
      state.appended = retainPages || more;
      state.updatedAt = _now();
      state.cached = false;
      if (query.isEmpty) {
        await storage.saveDocument(key, {
          'records': state.records.map((p) => p.data).toList(),
          'cursor': state.cursor,
          'hasMore': state.hasMore,
          'updatedAt': state.updatedAt!.toIso8601String(),
        });
      }
    } catch (e) {
      if (!_closed) state.error = e;
    } finally {
      state.loading = false;
      state.work = null;
      _notify();
    }
  }

  void clear() {
    _generation++;
    for (final entry in _pages.keys.where((e) => e.$2.isEmpty)) {
      final key =
          'catalog:${Uri.encodeComponent(cacheScope)}:${Uri.encodeComponent(entry.$1)}:';
      unawaited(storage.saveDocument(key, {}).catchError((Object _) {}));
    }
    _pages.clear();
    _notify();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

final class OrderCatalogPage {
  List<CompanyRecord> records = const [];
  String? cursor;
  bool hasMore = false, loading = false, cached = false, appended = false;
  DateTime? updatedAt;
  Object? error;
  Future<void>? work;
}

final class OrderCartController extends ChangeNotifier {
  OrderCartController({OrderValues? initial}) {
    for (final raw in initial?['cart'] as List? ?? []) {
      final p = CompanyRecord(Map<String, Object?>.from(raw as Map));
      final n =
          int.tryParse('${(initial?['quantities'] as Map?)?[p.id] ?? 1}') ?? 1;
      if (n > 0 && n <= 100000 && products.length < 20) {
        products[p.id] = p;
        quantity(p.id).value = n;
      }
    }
  }
  final Map<String, CompanyRecord> products = {};
  final Map<String, ValueNotifier<int>> _quantities = {};
  ValueNotifier<int> quantity(String id) =>
      _quantities.putIfAbsent(id, () => ValueNotifier(0));
  int get total => products.values.fold(
    0,
    (sum, p) => sum + p.number('priceCentavos') * quantity(p.id).value,
  );
  bool add(CompanyRecord p, {int count = 1, bool preserve = false}) {
    if (preserve && products.containsKey(p.id)) return true;
    if (!products.containsKey(p.id) && products.length >= 20) return false;
    final next = quantity(p.id).value + count;
    if (next < 1 || next > 100000) return false;
    final trace = TimelineTask()..start('ordering.cartEdit');
    products.putIfAbsent(p.id, () => p);
    quantity(p.id).value = next;
    notifyListeners();
    trace.finish();
    return true;
  }

  void setQuantity(String id, int value) {
    if (value < 0 || value > 100000 || !products.containsKey(id)) return;
    final trace = TimelineTask()..start('ordering.cartEdit');
    if (value == 0) products.remove(id);
    quantity(id).value = value;
    notifyListeners();
    trace.finish();
  }

  void replaceQuotes(List<CompanyRecord> fresh) {
    for (final p in fresh) {
      if (products.containsKey(p.id)) products[p.id] = p;
    }
    notifyListeners();
  }

  OrderValues snapshot() => {
    'cart': products.values.map((p) => p.data).toList(),
    'quantities': {for (final id in products.keys) id: quantity(id).value},
  };
  @override
  void dispose() {
    for (final q in _quantities.values) {
      q.dispose();
    }
    super.dispose();
  }
}

/// Queued snapshots cannot race a successful clear. Flush errors remain visible.
final class OrderDraftWriter {
  OrderDraftWriter(this.save);
  final Future<void> Function(OrderValues) save;
  Future<void> _work = Future.value();
  Timer? _timer;
  OrderValues? _latest;
  Object? error;
  bool _closed = false;
  void schedule(OrderValues values) {
    if (_closed) return;
    _latest = values;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), _enqueue);
  }

  void _enqueue() {
    _timer?.cancel();
    final values = _latest;
    _latest = null;
    if (values == null || _closed) return;
    _work = _work.then((_) async {
      try {
        await save(values);
        error = null;
      } catch (e) {
        error = e;
      }
    });
  }

  Future<void> flush() async {
    _enqueue();
    await _work;
    if (error != null) throw error!;
  }

  Future<void> close() async {
    await flush();
    _closed = true;
    _timer?.cancel();
  }
}

int suggestedCompanyQuantity(int stock, int factor) {
  if (factor < 1 || factor > 10000) throw ArgumentError.value(factor);
  return ((20 - stock) / factor).ceil().clamp(1, 100000);
}
