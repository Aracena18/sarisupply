import 'dart:developer';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

typedef CompanyPageReader =
    Future<CompanyPage> Function(
      String kind,
      String? warehouseId,
      String? cursor,
    );

/// One controller belongs to one authenticated business/role/revision context.
/// Never share it across accounts or authorization contexts.
final class CompanyOperationsController extends ChangeNotifier {
  CompanyOperationsController({
    required this.scope,
    required this.read,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final String scope;
  final CompanyPageReader read;
  final DateTime Function() _now;
  final Map<(String, String?), CompanyDatasetState> _datasets = {};
  final List<Completer<void>> _waiting = [];
  int _active = 0;
  bool _disposed = false;

  CompanyDatasetState dataset(String kind, {String? warehouseId}) =>
      _datasets.putIfAbsent((kind, warehouseId), CompanyDatasetState.new);

  void seed(String kind, List<CompanyRecord> records, {String? warehouseId}) {
    final state = dataset(kind, warehouseId: warehouseId);
    if (state.fetchedAt == null && state.records.isEmpty) {
      state.records = List.unmodifiable(records);
      state.cached = records.isNotEmpty;
    }
  }

  Future<void> _acquire() async {
    if (_active < 3) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _active--;
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Ordering shares the workspace's three-read budget without invalidating it.
  Future<T> limitRead<T>(Future<T> Function() work) async {
    await _acquire();
    try {
      if (_disposed) throw StateError('Workspace closed');
      return await work();
    } finally {
      _release();
    }
  }

  Future<CompanyPage> _read(
    String kind,
    String? warehouse,
    String? cursor,
  ) async {
    await _acquire();
    final trace = TimelineTask()..start('company.read.$kind');
    try {
      if (_disposed) throw StateError('Workspace closed');
      return await read(kind, warehouse, cursor);
    } finally {
      trace.finish();
      _release();
    }
  }

  Future<void> load(String kind, {String? warehouseId, bool force = false}) {
    final state = dataset(kind, warehouseId: warehouseId);
    if (_disposed) return Future.value();
    if (state._work != null) return state._work!;
    final ttl = ['warehouses', 'paymentInstructions'].contains(kind)
        ? const Duration(minutes: 5)
        : const Duration(seconds: 30);
    if (!force &&
        state.error == null &&
        state.fetchedAt != null &&
        _now().difference(state.fetchedAt!) < ttl) {
      return Future.value();
    }
    final generation = ++state._generation;
    state.refreshing = true;
    state.error = null;
    final work = _loadPages(kind, warehouseId, state, generation);
    state._work = work;
    _changed();
    return work;
  }

  Future<void> _loadPages(
    String kind,
    String? warehouse,
    CompanyDatasetState state,
    int generation,
  ) async {
    try {
      final records = <String, CompanyRecord>{};
      String? cursor;
      CompanyPage? page;
      var pages = 0;
      final count = state._pageCount;
      do {
        page = await _read(kind, warehouse, cursor);
        if (_disposed || generation != state._generation) return;
        for (final record in page.records) {
          records[record.id] = record;
        }
        cursor = page.nextCursor;
        pages++;
      } while (pages < count && cursor != null);
      state.records = List.unmodifiable(records.values);
      state.page = page;
      state._pageCount = pages;
      state.fetchedAt = _now();
      state.cached = false;
    } catch (e) {
      if (!_disposed && generation == state._generation) {
        state.error = e;
      }
      rethrow;
    } finally {
      if (!_disposed && generation == state._generation) {
        state.refreshing = false;
        state._work = null;
        _changed();
      }
    }
  }

  Future<void> more(String kind, {String? warehouseId}) {
    final state = dataset(kind, warehouseId: warehouseId);
    if (_disposed || state._work != null) return state._work ?? Future.value();
    final cursor = state.page?.nextCursor;
    if (cursor == null) return Future.value();
    final generation = ++state._generation;
    state.loadingMore = true;
    state.error = null;
    final work = _more(kind, warehouseId, cursor, state, generation);
    state._work = work;
    _changed();
    return work;
  }

  Future<void> _more(
    String kind,
    String? warehouse,
    String cursor,
    CompanyDatasetState state,
    int generation,
  ) async {
    try {
      final page = await _read(kind, warehouse, cursor);
      if (_disposed || generation != state._generation) return;
      final records = {for (final r in state.records) r.id: r};
      for (final r in page.records) {
        records[r.id] = r;
      }
      state.records = List.unmodifiable(records.values);
      state.page = page;
      state._pageCount++;
    } catch (e) {
      if (!_disposed && generation == state._generation) {
        state.error = e;
      }
      rethrow;
    } finally {
      if (!_disposed && generation == state._generation) {
        state.loadingMore = false;
        state._work = null;
        _changed();
      }
    }
  }

  void invalidate(String kind, {String? warehouseId}) {
    final state = dataset(kind, warehouseId: warehouseId);
    state._generation++;
    state._work = null;
    state.refreshing = state.loadingMore = false;
    state.fetchedAt = null;
    _changed();
  }

  void invalidateKind(String kind) {
    final keys = _datasets.keys.where((key) => key.$1 == kind).toList();
    for (final key in keys) {
      invalidate(kind, warehouseId: key.$2);
    }
  }

  /// Display state only. Durable drafts/outboxes are owned by storage.
  void clear() {
    for (final state in _datasets.values) {
      state._generation++;
    }
    _datasets.clear();
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    super.dispose();
  }
}

final class CompanyDatasetState {
  List<CompanyRecord> records = const [];
  CompanyPage? page;
  DateTime? fetchedAt;
  Object? error;
  bool refreshing = false, loadingMore = false, cached = false;
  bool get initialLoading => refreshing && records.isEmpty;
  int _generation = 0, _pageCount = 1;
  Future<void>? _work;
}
