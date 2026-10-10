import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'company_delivery_payment.dart';
import 'company_delivery_queue.dart';
import 'company_operations_controller.dart';
import 'company_navigation.dart';
import 'company_rider_route.dart';
import 'company_stock_header.dart';
import 'company_stock_product_details.dart';
import 'company_order_queue.dart';
import 'company_order_details.dart';
import 'order_shop_controller.dart';
import 'order_shop_screen.dart';
import 'item_requests_screen.dart';
import 'company_product_dialog.dart';
import 'work_storage_native.dart'
    if (dart.library.js_interop) 'work_storage_web.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

typedef Values = Map<String, Object?>;

enum _StockFilter { all, lowStock, outOfStock }

enum _StockSort { name, available, price }

enum _DeliveryQueueTab { unassigned, active, completed }

class CompanyOperationsScreen extends StatefulWidget {
  const CompanyOperationsScreen({
    super.key,
    required this.companyId,
    required this.title,
    required this.context,
    this.onMore,
    this.onAdministration,
    this.onSignOut,
    this.onExit,
    this.retailStore,
    this.controller,
    this.gateway,
    this.authorizationRevision = '',
  });
  final String companyId, title;
  final Values context;
  final Future<void> Function()? onMore, onSignOut;
  final Future<int?> Function()? onAdministration;
  final VoidCallback? onExit;
  final InventoryStore? retailStore;
  final CompanyOperationsController? controller;
  final CompanyOperationsFunctions? gateway;
  final String authorizationRevision;
  @override
  State<CompanyOperationsScreen> createState() =>
      _CompanyOperationsScreenState();
}

class _CompanyOperationsScreenState extends State<CompanyOperationsScreen>
    with WidgetsBindingObserver {
  late final _gateway =
      widget.gateway ?? CompanyOperationsFunctions.forDefaultApp();
  CompanyOperationsController? _controller;
  OrderCatalogController? _orderingCatalog;
  bool _refreshing = false, _syncingProofs = false, _denied = false;
  final Set<String> _savingTargets = {};
  final Map<String, List<CompanyRecord>> _pickerRecords = {};
  final Map<String, CompanyPage> _pickerPages = {};
  final Map<String, double> _scrollPositions = {};
  final Set<String> _expandedRuns = {};
  final ScrollController _scroll = ScrollController();
  final TextEditingController _orderSearchController = TextEditingController();
  final TextEditingController _stockSearchController = TextEditingController();
  final TextEditingController _deliverySearchController =
      TextEditingController();
  final FocusNode _orderSearchFocus = FocusNode();
  String? _uid;
  DateTime? _verifiedRunRead, _savedAt;
  Future<void>? _proofWork;
  final Set<Future<void>> _work = {};
  Timer? _riderRunRefreshTimer;
  final Map<String, CompanyRecord> _pendingRuns = {};
  CompanyWorkStorage? _local;
  List<CompanyRecord> _warehouses = [],
      _products = [],
      _orders = [],
      _runs = [];
  final Map<String, CompanyPage> _pages = {};
  String? _warehouse, _error, _message;
  String _paymentInstructions = '';
  bool _loading = true,
      _saving = false,
      _cached = false,
      _offlineProofAllowed = false;
  String _storeOrderFilter = 'all';
  bool _orderSearchOpen = false,
      _filterUnpaidOrders = false,
      _filterReceiptReview = false,
      _includeOtherOrderStatuses = false;
  CompanyOrderQueueTab _selectedOrderTab = CompanyOrderQueueTab.awaiting;
  _DeliveryQueueTab _selectedDeliveryTab = _DeliveryQueueTab.unassigned;
  bool _deliveryNeedsReviewOnly = false;
  _StockFilter _selectedStockFilter = _StockFilter.all;
  _StockSort? _stockSort;
  int _tab = 0, _generation = 0;
  bool get _store => widget.context['kind'] == 'store';
  bool get _rider => widget.context['role'] == 'rider';
  bool get _owner => widget.context['role'] == 'companyOwner';
  bool get _redesignedOrders =>
      !_store &&
      !_rider &&
      (_owner || _context['role'] == 'warehouseOperations') &&
      _tab == 0;
  bool get _redesignedStock =>
      !_store &&
      !_rider &&
      (_owner || _context['role'] == 'warehouseOperations') &&
      _tab == 1;
  bool get _operationsRedesignHeader =>
      _redesignedOrders || _redesignedStock || _redesignedDeliveries;
  bool get _redesignedDeliveries =>
      !_store &&
      !_rider &&
      (_owner || _context['role'] == 'warehouseOperations') &&
      _tab == 2;
  Values get _context => widget.context;
  @override
  void didUpdateWidget(covariant CompanyOperationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId ||
        jsonEncode(oldWidget.context) != jsonEncode(widget.context) ||
        oldWidget.authorizationRevision != widget.authorizationRevision) {
      _generation++;
      _denied = true;
      _offlineProofAllowed = false;
      _controller?.clear();
      _orderingCatalog?.clear();
      _warehouses = [];
      _products = [];
      _orders = [];
      _runs = [];
      _pickerRecords.clear();
      _pickerPages.clear();
      _pendingRuns.clear();
      _error = 'Your access has changed. Reopen this workspace.';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_rider) {
      _riderRunRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted ||
            _controller == null ||
            _denied ||
            _refreshing ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          return;
        }
        unawaited(_refresh(force: false, kinds: {'runs'}));
      });
    }
    _open();
  }

  Future<Map<String, Object?>?> _clock() async {
    try {
      return await const MethodChannel(
        'sarisupply/offline_clock',
      ).invokeMapMethod<String, Object?>('read');
    } catch (_) {
      return null;
    }
  }

  Future<void> _open() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sign in to open this workspace');
      final role = _store
          ? 'store-${_context['merchantId']}-${_context['branchId']}'
          : _context['role'] as String;
      final local = await openCompanyWorkStorage(
        companyId: widget.companyId,
        uid: uid,
        role: role,
      );
      if (!mounted) {
        await local.close();
        return;
      }
      _local = local;
      _uid = uid;
      final scope = jsonEncode([
        uid,
        widget.companyId,
        _context,
        widget.authorizationRevision,
      ]);
      if (widget.controller != null && widget.controller!.scope != scope) {
        throw StateError('Workspace cache scope mismatch');
      }
      _controller =
          widget.controller ??
          CompanyOperationsController(
            scope: scope,
            read: (kind, warehouse, cursor) => _gateway.read(
              companyId: widget.companyId,
              context: _context,
              kind: kind,
              warehouseId: warehouse,
              cursor: cursor,
            ),
          );
      _controller!.addListener(_display);
      if (_store) {
        _orderingCatalog = OrderCatalogController(
          storage: local,
          cacheScope: widget.authorizationRevision,
          read: (warehouse, query, cursor) => _orderingRead(
            'catalog',
            warehouse: warehouse,
            search: query,
            cursor: cursor,
          ),
        );
      }

      final cached = await local.document('workspace');
      if (!mounted) return;
      // A disk snapshot is display evidence, never a new authorization grant.
      if (cached != null &&
          (cached['authorizationRevision'] == widget.authorizationRevision ||
              (cached['authorizationRevision'] == null &&
                  widget.authorizationRevision.isEmpty))) {
        _savedAt = DateTime.tryParse(cached['savedAt'] as String? ?? '');
        _warehouse = cached['warehouse'] as String?;
        final permitted = !_rider || await local.offlineAllowed(await _clock());
        if (permitted) {
          for (final kind in ['warehouses', 'products', 'orders', 'runs']) {
            final raw = cached[kind] as List? ?? [];
            _controller!.seed(
              kind,
              raw
                  .map(
                    (r) => CompanyRecord(Map<String, Object?>.from(r as Map)),
                  )
                  .toList(),
              warehouseId: _scopeWarehouse(kind),
            );
          }
          _paymentInstructions = cached['paymentInstructions'] as String? ?? '';
          _offlineProofAllowed = _rider && permitted;
          _cached = true;
          _display();
          if (_rider) await _overlayPending();
          if (mounted) setState(() => _loading = false);
        }
      }
      await _refresh(force: false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = operationErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<CompanyPage> _read(String kind, {String? cursor}) => _gateway.read(
    companyId: widget.companyId,
    context: _context,
    kind: kind,
    warehouseId: _scopeWarehouse(kind),
    cursor: cursor,
  );

  String get _visibleKind => _rider
      ? 'runs'
      : _store
      ? 'orders'
      : _tab == 0
      ? 'orders'
      : _tab == 1
      ? 'products'
      : 'runs';
  String? _scopeWarehouse(String kind) =>
      _store || _rider || kind == 'warehouses' || kind == 'paymentInstructions'
      ? null
      : _warehouse;
  bool get _current =>
      mounted && _uid == FirebaseAuth.instance.currentUser?.uid;

  void _display() {
    if (!_current || _controller == null || _denied) return;
    final c = _controller!;
    setState(() {
      _warehouses = c.dataset('warehouses').records;
      _products = c
          .dataset('products', warehouseId: _scopeWarehouse('products'))
          .records;
      _orders = c
          .dataset('orders', warehouseId: _scopeWarehouse('orders'))
          .records;
      _runs = c
          .dataset('runs', warehouseId: _scopeWarehouse('runs'))
          .records
          .map((r) => _pendingRuns[r.id] ?? r)
          .toList();
      _pages.clear();
      for (final kind in ['products', 'orders', 'runs']) {
        final state = c.dataset(kind, warehouseId: _scopeWarehouse(kind));
        if (state.page != null) _pages[kind] = state.page!;
      }
      final payment = c.dataset('paymentInstructions');
      if (payment.records.isNotEmpty) {
        _paymentInstructions = payment.records.first.string('instructions');
      }
      final active = c.dataset(
        _visibleKind,
        warehouseId: _scopeWarehouse(_visibleKind),
      );
      _loading = active.initialLoading;
      _refreshing = active.refreshing || active.loadingMore;
      _cached = active.cached;
    });
  }

  Future<void> _accessFailure(Object e) async {
    if (!_current) return;
    if (e is FirebaseException &&
        ['permission-denied', 'unauthenticated'].contains(e.code)) {
      _denied = true;
      _offlineProofAllowed = false;
      _controller?.clear();
      _orderingCatalog?.clear();
      _pickerRecords.clear();
      _pickerPages.clear();
      _warehouses = [];
      _products = [];
      _orders = [];
      _runs = [];
      await _local?.invalidateAuthority();
      await _local?.saveDocument('workspace', {});
    }
    if (_current) setState(() => _error = operationErrorMessage(e));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _controller != null) {
      unawaited(_refresh(force: false));
    }
  }

  Future<void> _track(Future<void> Function() action) {
    final work = action();
    _work.add(work);
    return work.whenComplete(() => _work.remove(work));
  }

  Future<void> _refresh({bool force = true, Set<String>? kinds}) =>
      _track(() => _refreshNow(force: force, kinds: kinds));

  Future<void> _refreshNow({bool force = true, Set<String>? kinds}) async {
    if (!_current || _controller == null || _denied) return;
    final generation = ++_generation;
    final c = _controller!;
    setState(() => _error = null);
    try {
      if (!_rider && kinds == null) {
        await c.load('warehouses', force: force);
        if (!_current || generation != _generation || _denied) return;
        _warehouses = c.dataset('warehouses').records;
        if (!_warehouses.any((w) => w.id == _warehouse)) {
          _warehouse = _warehouses.length == 1 ? _warehouses.single.id : null;
        }
      }
      final wanted =
          kinds ??
          {
            if (_rider || _store || _warehouse != null) _visibleKind,
            if (_store) ...['products', 'paymentInstructions'],
          };
      await Future.wait(
        wanted.map(
          (kind) =>
              c.load(kind, warehouseId: _scopeWarehouse(kind), force: force),
        ),
      );
      if (!_current || generation != _generation || _denied) return;
      _display();
      if (_rider) {
        final clock = await _clock();
        // Only a fresh server run read renews the existing offline window.
        final runs = c.dataset('runs');
        if (runs.error == null &&
            runs.fetchedAt != null &&
            runs.fetchedAt != _verifiedRunRead &&
            clock != null) {
          await _local!.verifyAuthority(clock);
          _verifiedRunRead = runs.fetchedAt;
        }
        _offlineProofAllowed = await _local!.offlineAllowed(clock);
        final pending = await _local!.pending();
        final pendingRuns = pending
            .map((o) => (jsonDecode(o['payload'] as String) as Map)['runId'])
            .toSet();
        for (final run in c.dataset('runs').records) {
          if (!pendingRuns.contains(run.id)) {
            await _local!.saveDocument('run:${run.id}', run.data);
          }
        }
        await _overlayPending();
        unawaited(_uploadProofs());
      }
      if (!_current || generation != _generation || _denied) return;
      await _local!.saveDocument('workspace', {
        'warehouses': _warehouses.map((r) => r.data).toList(),
        'products': _products.map((r) => r.data).toList(),
        'orders': _orders.map((r) => r.data).toList(),
        'runs': _runs.map((r) => r.data).toList(),
        'warehouse': _warehouse,
        'paymentInstructions': _paymentInstructions,
        'authorizationRevision': widget.authorizationRevision,
        'savedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // A denial from any request remains definitive even after tab switching.
      await _accessFailure(e);
      if (_current &&
          generation == _generation &&
          isRetryableOperationError(e)) {
        _cached = true;
      }
    } finally {
      if (_current && generation == _generation) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _more(String kind) async {
    if (_controller == null || _denied) return;
    try {
      await _controller!.more(kind, warehouseId: _scopeWarehouse(kind));
      if (_current) {
        _display();
        if (_rider) await _overlayPending();
      }
    } catch (e) {
      await _accessFailure(e);
    }
  }

  Future<void> _uploadProofs() {
    if (_proofWork != null) return _proofWork!;
    final work = _uploadProofsNow();
    _proofWork = work;
    return work.whenComplete(() => _proofWork = null);
  }

  Future<void> _uploadProofsNow() async {
    if (_syncingProofs || !_current || _denied) return;
    _syncingProofs = true;
    try {
      if (await _syncProofs() && _current && !_denied) {
        _controller!.invalidate('runs');
        await _refresh(force: true, kinds: {'runs'});
      }
    } catch (e) {
      await _accessFailure(e);
    } finally {
      _syncingProofs = false;
      if (_current) setState(() {});
    }
  }

  Future<void> _overlayPending() async {
    final pending = await _local!.pending();
    _pendingRuns.clear();
    if (_controller != null) {
      _runs = _controller!.dataset('runs').records.toList();
    }
    for (final op in pending) {
      final payload = Map<String, Object?>.from(
        jsonDecode(op['payload'] as String) as Map,
      );
      final runId = payload['runId'];
      final local = await _local!.document('run:$runId');
      if (local != null) {
        _pendingRuns[runId as String] = CompanyRecord(local);
        final i = _runs.indexWhere((r) => r.id == runId);
        if (i >= 0) _runs[i] = CompanyRecord(local);
      }
    }
  }

  Future<bool> _syncProofs() async {
    var changed = false;
    for (final op in await _local!.pending()) {
      if (op['status'] == 'blocked') continue;
      final values = Map<String, Object?>.from(
        jsonDecode(op['payload'] as String) as Map,
      );
      final operationId = op['id'] as String;
      try {
        await _gateway.mutate(
          companyId: widget.companyId,
          context: _context,
          action: 'recordProof',
          operationId: operationId,
          values: values,
        );
        await _local!.acknowledge(operationId);
        changed = true;
      } catch (e) {
        if (!isRetryableOperationError(e)) {
          await _local!.block(operationId, operationErrorMessage(e));
          await _accessFailure(e);
          if (_denied) break;
        } else {
          break;
        }
      }
    }
    final pending = await _local!.pending();
    if (pending.isNotEmpty) {
      _message =
          '${pending.length} delivery record(s) ${pending.any((p) => p['status'] == 'blocked') ? 'need review' : 'saved locally · Sync pending'}';
    }
    if (_current) setState(() {});
    return changed;
  }

  void _showNotice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _mutate(String action, Values values) =>
      _track(() => _mutateNow(action, values));

  Future<void> _mutateNow(String action, Values values) async {
    if (_denied || !_current) return;
    final target =
        '${values['orderId'] ?? values['runId'] ?? values['productId'] ?? action}';
    if (!_savingTargets.add(target)) return;
    final key =
        'operation:$action:${values['orderId'] ?? values['runId'] ?? values['productId'] ?? 'new'}';
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final previous = await _local!.draft(key);
      final operationId =
          previous?['operationId'] as String? ?? const Uuid().v4();
      final payload = previous == null
          ? values
          : Map<String, Object?>.from(previous['values'] as Map);
      await _local!.saveDraft(key, {
        'operationId': operationId,
        'values': payload,
        'warehouseId': previous == null
            ? (_store || _rider ? null : _warehouse)
            : previous['warehouseId'],
      });
      await _gateway.mutate(
        companyId: widget.companyId,
        context: _context,
        action: action,
        operationId: operationId,
        values: payload,
        warehouseId: previous == null
            ? (_store || _rider ? null : _warehouse)
            : previous['warehouseId'] as String?,
      );
      await _local!.clearDraft(key);
      _showNotice(
        previous == null
            ? 'Saved'
            : 'Previous submission confirmed. Review any further changes.',
      );
      final affected = action == 'submitOrder'
          ? {'orders'}
          : action == 'saveProduct'
          ? {'products'}
          : [
              'receiveStock',
              'correctStock',
              'releaseQuarantine',
              'writeOffTransit',
            ].contains(action)
          ? {'products'}
          : action == 'savePaymentInstructions'
          ? {'paymentInstructions'}
          : values.containsKey('runId') ||
                ['createRun', 'dispatchRun'].contains(action)
          ? {'runs', 'orders', 'products'}
          : {'orders', 'products'};
      if (affected.contains('products')) {
        _pickerRecords.clear();
        _pickerPages.clear();
      }
      if (action == 'saveProduct') _controller!.invalidateKind('products');
      for (final kind in affected) {
        _controller!.invalidate(kind, warehouseId: _scopeWarehouse(kind));
      }
      // Refresh visible affected data only; other tabs refresh on next entry.
      unawaited(
        _refresh(
          force: true,
          kinds: affected
              .where(
                (kind) =>
                    kind == _visibleKind || (_store && kind == 'products'),
              )
              .toSet(),
        ),
      );
    } catch (e) {
      await _accessFailure(e);
      if (!_denied && !isRetryableOperationError(e)) {
        await _local!.clearDraft(key);
      }
      if (mounted) setState(() => _error = operationErrorMessage(e));
    } finally {
      _savingTargets.remove(target);
      if (mounted) setState(() => _saving = _savingTargets.isNotEmpty);
    }
  }

  Future<Values?> _form(
    String key,
    String title,
    List<_Field> fields, {
    String action = 'Save',
    String? explanation,
  }) async {
    final draft = await _local!.draft('form:$key');
    if (!mounted) return null;
    return Navigator.of(context).push<Values>(
      MaterialPageRoute(
        builder: (_) => _WorkForm(
          title: title,
          fields: fields,
          initial: draft,
          onDraft: (v) => _local!.saveDraft('form:$key', v),
          action: action,
          explanation: explanation,
        ),
      ),
    );
  }

  _Field _text(
    String key,
    String label, {
    String initial = '',
    bool optional = false,
  }) => _Field(key, label, initial: initial, optional: optional);
  _Field _count(String key, String label, {int initial = 0}) =>
      _Field(key, label, initial: '$initial', kind: 'integer');
  _Field _money(String key, String label, {int initial = 0}) => _Field(
    key,
    label,
    initial: (initial / 100).toStringAsFixed(2),
    kind: 'money',
  );
  _Field _choice(
    String key,
    String label,
    List<CompanyRecord> records, {
    String initial = '',
  }) => _Field(
    key,
    label,
    initial: initial,
    options: {
      for (final r in records)
        r.id: r.string('name').isEmpty ? r.id : r.string('name'),
    },
  );
  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _product() async {
    final values = await CompanyProductDialog.show(context);
    if (values != null) {
      final pending = await _local!.draft('new-product-id');
      final id = pending?['id'] as String? ?? 'product-${const Uuid().v4()}';
      await _local!.saveDraft('new-product-id', {'id': id});
      await _mutate('saveProduct', {
        'name': values['name'],
        'sku': values['sku'],
        'unit': values['unit'],
        'priceCentavos': values['priceCentavos'],
        'imageUrl': values['imageUrl'],
        'productId': id,
        'expectedRevision': 0,
      });
      if (_error == null) {
        await _local!.clearDraft('new-product-id');
        await _local!.clearDraft('form:product');
      }
    }
  }

  /// Owner edit of name, wholesale price and photo. SKU and base unit stay
  /// locked; the trusted backend rejects changes to them.
  Future<void> _editProduct(CompanyRecord product) async {
    final values = await CompanyProductDialog.show(context, product: product);
    if (values != null) {
      await _mutate('saveProduct', {
        'name': values['name'],
        'sku': product.string('sku'),
        'unit': product.string('unit'),
        'priceCentavos': values['priceCentavos'],
        'imageUrl': values['imageUrl'],
        'productId': product.id,
        'expectedRevision': product.revision,
      });
    }
  }

  Future<void> _stockAction(CompanyRecord product, String action) async {
    final values = await _form(
      '$action:${product.id}',
      action == 'releaseQuarantine'
          ? 'Release inspected stock'
          : action == 'correctStock'
          ? 'Correct physical stock'
          : action == 'writeOffTransit'
          ? 'Write off missing transit stock'
          : 'Receive warehouse stock',
      [
        _Field(
          'quantity',
          action == 'correctStock'
              ? 'Signed quantity change (${product.string('unit')})'
              : 'Quantity (${product.string('unit')})',
          initial: '0',
          kind: action == 'correctStock' ? 'signed' : 'integer',
        ),
        _text('reference', 'Invoice, opening count or inspection reference'),
      ],
    );
    if (values != null) {
      await _mutate(action, {
        ...values,
        'productId': product.id,
        'warehouseId': _warehouse,
      });
    }
  }

  Future<CompanyPage> _orderingRead(
    String kind, {
    String? warehouse,
    String? cursor,
    String? search,
    List<String>? ids,
  }) async {
    if (!_current || _denied) {
      throw StateError('Refresh access before continuing.');
    }
    try {
      final page = await _controller!.limitRead(
        () => _gateway.read(
          companyId: widget.companyId,
          context: _context,
          kind: kind,
          warehouseId: warehouse,
          cursor: cursor,
          search: search,
          productIds: ids,
        ),
      );
      if (!_current || _denied) {
        throw StateError('Access changed. Your draft is preserved.');
      }
      return page;
    } catch (e) {
      await _accessFailure(e);
      rethrow;
    }
  }

  Future<List<CompanyRecord>> _orderingMappings() async {
    final records = <CompanyRecord>[];
    String? cursor;
    do {
      final page = await _orderingRead('productMappings', cursor: cursor);
      records.addAll(page.records);
      cursor = page.nextCursor;
    } while (cursor != null && _current && !_denied);
    final mapped = {for (final r in records) r.id: r};
    for (final order in _orders) {
      for (final line in order.records('receivedLines')) {
        final retail = line['retailProductId'];
        final factor = line['retailUnitsPerCompanyUnit'];
        if (retail is String &&
            factor is int &&
            factor > 0 &&
            line['quantity'] is int &&
            (line['quantity'] as int) > 0) {
          mapped.putIfAbsent(
            retail,
            () => CompanyRecord({'id': retail, ...line}),
          );
        }
      }
    }
    return mapped.values.toList();
  }

  Future<void> _commitOrdering(
    String action,
    Values values, {
    String target = 'new',
  }) async {
    if (!_current || _denied) {
      throw StateError('Sign in and refresh access before submitting.');
    }
    final key = 'ordering-operation:$action:$target';
    if (!_savingTargets.add(key)) {
      throw StateError('Submission is already in progress.');
    }
    final work = _commitOrderingNow(action, values, key);
    _work.add(work);
    try {
      await work;
    } finally {
      _savingTargets.remove(key);
      _work.remove(work);
    }
  }

  Future<void> _commitOrderingNow(
    String action,
    Values values,
    String key,
  ) async {
    try {
      final previous = await _local!.draft(key);
      if (previous != null &&
          jsonEncode(previous['values']) != jsonEncode(values)) {
        throw StateError(
          'Previous submission is pending. Retry its original details first.',
        );
      }
      final id = previous?['operationId'] as String? ?? const Uuid().v4();
      await _local!.saveDraft(key, {'operationId': id, 'values': values});
      if (!_current || _denied) {
        throw StateError('Access changed. Your draft is preserved.');
      }
      await _gateway.mutate(
        companyId: widget.companyId,
        context: _context,
        action: action,
        operationId: id,
        values: values,
      );
      if (!['submitOrder', 'submitItemRequest'].contains(action)) {
        await _local!.clearDraft(key);
      }
    } catch (e) {
      await _accessFailure(e);
      if (!_denied && !isRetryableOperationError(e) && e is! StateError) {
        await _local!.clearDraft(key);
      }
      rethrow;
    }
  }

  Future<void> _newOrder({String? productId}) async {
    if (_warehouses.isEmpty || _orderingCatalog == null || _denied) return;
    final draft = await _local!.draft('form:order');
    final defaults = await _local!.document('orderingPreferences');
    final pending = await _local!.draft('ordering-operation:submitOrder:new');
    var initial = draft;
    if (initial == null && defaults != null) {
      initial = {...defaults, 'notes': ''};
    }
    if (productId != null && pending == null) {
      final wh =
          initial?['warehouseId'] as String? ??
          (_warehouses.length == 1 ? _warehouses.single.id : null);
      if (wh != null) {
        final products = (await _orderingRead(
          'selectedProducts',
          warehouse: wh,
          ids: [productId],
        )).records;
        if (products.isNotEmpty && products.single.data['active'] == true) {
          final cart = OrderCartController(initial: initial);
          cart.add(products.single);
          initial = {...?initial, 'warehouseId': wh, ...cart.snapshot()};
          cart.dispose();
        }
      }
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrderShopScreen(
          title: widget.title,
          hasAccess: () => _current && !_denied,
          warehouses: _warehouses,
          catalog: _orderingCatalog!,
          initial: initial,
          paymentInstructions: _paymentInstructions,
          pendingSubmission: pending == null
              ? null
              : Map<String, Object?>.from(pending['values'] as Map),
          retailStore: widget.retailStore,
          saveDraft: (v) => _local!.saveDraft('form:order', v),
          clearDraft: () async {
            await _local!.clearDraft('form:order');
            await _local!.clearDraft('ordering-operation:submitOrder:new');
          },
          loadPreferences: () async {
            try {
              final prefs = (await _orderingRead(
                'orderingPreferences',
              )).records.single.data;
              await _local!.saveDocument('orderingPreferences', prefs);
              return prefs;
            } catch (e) {
              await _accessFailure(e);
              if (_denied) rethrow;
              return defaults ?? {};
            }
          },
          loadMappings: () async {
            try {
              final records = await _orderingMappings();
              await _local!.saveDocument('productMappings', {
                'records': records.map((r) => r.data).toList(),
              });
              return records;
            } catch (e) {
              await _accessFailure(e);
              if (_denied) rethrow;
              final saved = await _local!.document('productMappings');
              return (saved?['records'] as List? ?? [])
                  .map(
                    (r) => CompanyRecord(Map<String, Object?>.from(r as Map)),
                  )
                  .toList();
            }
          },
          validateProducts: (wh, ids) async {
            try {
              return (await _orderingRead(
                'selectedProducts',
                warehouse: wh,
                ids: ids,
              )).records;
            } catch (e) {
              await _accessFailure(e);
              rethrow;
            }
          },
          submit: (v) async {
            await _commitOrdering('submitOrder', v);
            await _local!.saveDocument('orderingPreferences', {
              for (final k in ['warehouseId', 'address', 'contact', 'phone'])
                k: v[k],
            });
          },
          matchProduct: (row) async {
            final product = await _pickCompanyProduct();
            if (product == null) return null;
            final form = await _form(
              'mapping:${row.product.id}',
              'Match ${row.product.name}',
              [
                _count(
                  'factor',
                  'Retail ${row.product.baseUnit} per company ${product.string('unit')}',
                  initial: 1,
                ),
              ],
              action: 'Confirm product match',
              explanation:
                  '${row.product.name} matches ${product.string('name')}. Confirm units; names alone do not establish a match.',
            );
            if (form == null ||
                form['factor'] is! int ||
                (form['factor'] as int) < 1 ||
                (form['factor'] as int) > 10000) {
              return null;
            }
            final mapping = <String, Object?>{
              'retailProductId': row.product.id,
              'productId': product.id,
              'retailUnitsPerCompanyUnit': form['factor'],
            };
            await _commitOrdering(
              'saveProductMapping',
              mapping,
              target: row.product.id,
            );
            return CompanyRecord({
              'id': row.product.id,
              ...mapping,
              'product': product.data,
            });
          },
        ),
      ),
    );
    if (saved == true && _current) {
      _showNotice('Order submitted · Awaiting warehouse acceptance');
      _controller!.invalidate('orders');
      unawaited(_refresh(kinds: {'orders'}));
    }
  }

  Future<void> _openItemRequests() async {
    if (_denied || _local == null || (!_store && _warehouse == null)) return;
    final selectedWarehouse = _warehouse;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ItemRequestsScreen(
          store: _store,
          read: (cursor) async {
            try {
              return await _orderingRead(
                'itemRequests',
                warehouse: _store ? null : selectedWarehouse,
                cursor: cursor,
              );
            } catch (e) {
              await _accessFailure(e);
              rethrow;
            }
          },
          create: () async {
            final pending = await _local!.draft(
              'ordering-operation:submitItemRequest:new',
            );
            if (pending != null) {
              await _commitOrdering(
                'submitItemRequest',
                Map<String, Object?>.from(pending['values'] as Map),
              );
              await _local!.clearDraft('form:itemRequest');
              await _local!.clearDraft(
                'ordering-operation:submitItemRequest:new',
              );
              return;
            }
            final defaults =
                await _local!.document('orderingPreferences') ?? {};
            final values = await _form(
              'itemRequest',
              'Request an item',
              [
                _choice(
                  'warehouseId',
                  'Supplying warehouse',
                  _warehouses,
                  initial: defaults['warehouseId'] as String? ?? '',
                ),
                _text('name', 'Item name'),
                _count('quantity', 'Desired quantity', initial: 1),
                _text('unit', 'Unit / pack size'),
                _text(
                  'details',
                  'Brand, size and notes (optional)',
                  optional: true,
                ),
                _text(
                  'contact',
                  'Recipient name',
                  initial: defaults['contact'] as String? ?? '',
                ),
                _text(
                  'phone',
                  'Contact number',
                  initial: defaults['phone'] as String? ?? '',
                ),
              ],
              action: 'Submit request',
              explanation: 'This is a sourcing request, not a purchase.',
            );
            if (values == null) return;
            await _commitOrdering('submitItemRequest', values);
            await _local!.clearDraft('form:itemRequest');
            await _local!.clearDraft(
              'ordering-operation:submitItemRequest:new',
            );
          },
          respond: (request, close) async {
            final action = close ? 'closeItemRequest' : 'respondItemRequest';
            final pending = await _local!.draft(
              'ordering-operation:$action:${request.id}',
            );
            if (pending != null) {
              await _commitOrdering(
                action,
                Map<String, Object?>.from(pending['values'] as Map),
                target: request.id,
              );
              return;
            }
            final form = await _form(
              'request:${request.id}',
              close ? 'Close request' : 'Respond to request',
              [
                _text(
                  'response',
                  'Warehouse response',
                  initial: request.string('response'),
                ),
                if (!close)
                  _Field(
                    'productId',
                    'Link catalog product (optional)',
                    picker: _pickCompanyProduct,
                    optional: true,
                  ),
              ],
              action: close ? 'Close request' : 'Send response',
            );
            if (form == null) return;
            await _commitOrdering(action, {
              'requestId': request.id,
              'expectedRevision': request.revision,
              ...form,
            }, target: request.id);
          },
          orderProduct: _store ? (id) => _newOrder(productId: id) : null,
        ),
      ),
    );
  }

  Future<CompanyRecord?> _pickCompanyProduct() =>
      Navigator.of(context).push<CompanyRecord>(
        MaterialPageRoute(
          builder: (_) => _ProductPicker(
            onError: _accessFailure,
            initialRecords: _controller!.dataset('products').records,
            initialPage: _controller!.dataset('products').page,
            load: (cursor, query) async {
              if (cursor == null) {
                await _controller!.load('products');
              } else {
                await _controller!.more('products');
              }
              final state = _controller!.dataset('products');
              return CompanyPage(
                records: state.records,
                nextCursor: state.page?.nextCursor,
                hasMore: state.page?.hasMore ?? false,
              );
            },
            company: true,
          ),
        ),
      );
  Future<CompanyRecord?> _pickRetailProduct(InventoryStore store) =>
      Navigator.of(context).push<CompanyRecord>(
        MaterialPageRoute(
          builder: (_) => _ProductPicker(
            initialRecords: _pickerRecords['retail'] ?? const [],
            initialPage: _pickerPages['retail'],
            onError: _accessFailure,
            load: (cursor, query) async {
              final rows = await store.search(query);
              final page = CompanyPage(
                records: rows
                    .map(
                      (r) => CompanyRecord({
                        'id': r.product.id,
                        'name': r.product.name,
                        'unit': r.product.baseUnit,
                      }),
                    )
                    .toList(),
                nextCursor: null,
                hasMore: false,
              );
              if (query.trim().isEmpty && _current && !_denied) {
                _pickerRecords['retail'] = page.records;
                _pickerPages['retail'] = page;
              }
              return page;
            },
            company: false,
          ),
        ),
      );

  Future<void> _orderAction(CompanyRecord order, String action) async {
    final values = <String, Object?>{
      'orderId': order.id,
      'expectedRevision': order.revision,
    };
    final items = order.records('lines');
    if (action == 'proposeOrder') {
      final form = await _form(
        'proposal:${order.id}',
        'Propose order changes',
        [
          for (final l in items) ...[
            _count(
              'q:${l['productId']}',
              "${l['name']} · quantity (${l['unit']})",
              initial: l['quantity'] as int,
            ),
            _money(
              'p:${l['productId']}',
              "${l['name']} · price per ${l['unit']}",
              initial: l['priceCentavos'] as int,
            ),
          ],
          _text('reason', 'Reason for changes'),
        ],
        action: 'Send for store approval',
        explanation:
            'Review each item’s quantity and unit price. Enter 0 to remove an unavailable item. Explain the changes; the store must approve before fulfillment continues.',
      );
      if (form == null) return;
      values['reason'] = form['reason'];
      values['lines'] = items
          .map(
            (l) => {
              'productId': l['productId'],
              'quantity': form['q:${l['productId']}'],
              'priceCentavos': form['p:${l['productId']}'],
            },
          )
          .toList();
    } else if (action == 'packOrder') {
      final form = await _form(
        'packing:${order.id}',
        'Confirm packed quantities',
        [
          _text('packageReference', 'Package label / reference'),
          for (final l in items)
            _count(
              'q:${l['productId']}',
              "${l['name']} · packed ${l['unit']} (ordered ${l['quantity']})",
              initial: l['quantity'] as int,
            ),
        ],
        action: 'Confirm packing',
        explanation:
            'Every accepted quantity must be packed. Report a shortage if an item is unavailable.',
      );
      if (form == null) return;
      values['packageReference'] = form['packageReference'];
      values['lines'] = items
          .map(
            (l) => {
              'productId': l['productId'],
              'quantity': form['q:${l['productId']}'],
            },
          )
          .toList();
    } else if (action == 'confirmQr') {
      final form = await _form(
        'qr:${order.id}',
        'Confirm QR payment',
        [
          _money('amountCentavos', 'Verified amount'),
          _text('reference', 'Transaction reference'),
        ],
        action: 'Confirm payment',
        explanation:
            'Confirm only a payment you have verified in the receiving account.',
      );
      if (form == null) return;
      values.addAll(form);
    } else if (action == 'cancelOrder' || action == 'rejectOrder') {
      final form = await _form(
        'cancel:${order.id}',
        action == 'cancelOrder' ? 'Cancel order' : 'Reject order',
        [_text('reason', 'Reason')],
        action: 'Confirm',
      );
      if (form == null) return;
      values.addAll(form);
    } else if (action == 'confirmReceipt') {
      final store = widget.retailStore;
      if (store == null) return;
      final evidence = Map<String, Object?>.from(
        order.data['deliveryEvidence'] as Map,
      );
      final delivered = (evidence['items'] as List).cast<Map>();
      final form = await _form(
        'receipt:${order.id}',
        'Confirm goods received',
        [
          for (final l in items) ...[
            _count(
              'q:${l['productId']}',
              '${l['name']} · received ${l['unit']}',
              initial:
                  (delivered.firstWhere(
                        (d) => d['productId'] == l['productId'],
                      )['quantityDelivered']
                      as int),
            ),
            _Field(
              'r:${l['productId']}',
              'Your retail product',
              picker: () => _pickRetailProduct(store),
              requiredQuantityKey: 'q:${l['productId']}',
            ),
            _count(
              'f:${l['productId']}',
              'Retail base units per company ${l['unit']}',
              initial: 1,
            ),
          ],
        ],
        action: 'Review receipt',
        explanation:
            'Confirm what you actually accepted. Select the matching retail product and conversion. Offline entries remain drafts until online confirmation.',
      );
      if (form == null) return;
      if (!mounted ||
          !await _confirm(
            'Confirm receipt?',
            'These quantities will be added to this store branch once. Differences remain visible for warehouse review.',
          )) {
        return;
      }
      values['lines'] = items
          .map(
            (l) => {
              'productId': l['productId'],
              'quantity': form['q:${l['productId']}'],
              'retailProductId': form['r:${l['productId']}'],
              'retailUnitsPerCompanyUnit': form['f:${l['productId']}'],
            },
          )
          .toList();
    } else if (!await _confirm(
      _actionLabel(action),
      action == 'confirmProposal'
          ? 'Confirm the revised quantities and wholesale prices shown above?'
          : action == 'acceptOrder'
          ? 'Accept these items and quantities? Stock will be reserved for this order.'
          : action == 'startPicking'
          ? 'Begin collecting the accepted items. Confirm the packed quantities when ready, or report a shortage for store approval.'
          : 'Continue with this order?',
    )) {
      return;
    }
    await _mutate(action, values);
  }

  Future<bool> _dependency(String kind) async {
    final warehouse = _warehouse;
    try {
      await _controller!.load(kind, warehouseId: _scopeWarehouse(kind));
      return _current && !_denied && warehouse == _warehouse;
    } catch (e) {
      await _accessFailure(e);
      return false;
    }
  }

  Future<void> _newRun() async {
    if (!await _dependency('orders')) return;
    final packed = _orders
        .where((o) => o.status == 'packed' && o.data['runId'] == null)
        .toList();
    if (packed.isEmpty) {
      setState(() => _error = 'Pack orders before assigning a delivery.');
      return;
    }
    try {
      final riders = await _read('riders');
      if (riders.records.isEmpty) {
        setState(
          () => _error =
              'Invite a rider and have them accept warehouse access before assigning deliveries.',
        );
        return;
      }
      final values = await _form(
        'run',
        'Assign delivery',
        [
          _choice('driverId', 'Rider', riders.records),
          _text('vehicleInfo', 'Vehicle / plate'),
          for (final o in packed)
            _count(
              'sequence:${o.id}',
              '${o.string('storeName')} · ${o.string('packageReference')} · stop order (0 to omit)',
            ),
        ],
        action: 'Review delivery',
        explanation:
            'Number selected stops from 1. Use 0 for orders not included in this run.',
      );
      if (values == null) return;
      final selected =
          packed.where((o) => (values['sequence:${o.id}'] as int) > 0).toList()
            ..sort(
              (a, b) => (values['sequence:${a.id}'] as int).compareTo(
                values['sequence:${b.id}'] as int,
              ),
            );
      final positions = selected.map((o) => values['sequence:${o.id}']).toSet();
      if (selected.isEmpty ||
          selected.length > 20 ||
          positions.length != selected.length) {
        setState(
          () => _error = 'Choose 1–20 stops with distinct sequence numbers.',
        );
        return;
      }
      final rider = riders.records.firstWhere(
        (r) => r.id == values['driverId'],
      );
      if (!mounted ||
          !await _confirm(
            'Create delivery?',
            '${rider.string('name')} · ${values['vehicleInfo']}\n${selected.map((o) => o.string('storeName')).join(' → ')}\nStock leaves availability only when you dispatch.',
          )) {
        return;
      }
      if (mounted) {
        setState(() => _selectedDeliveryTab = _DeliveryQueueTab.unassigned);
      }
      await _mutate('createRun', {
        'warehouseId': _warehouse,
        'driverId': rider.id,
        'driverName': rider.string('name'),
        'vehicleInfo': values['vehicleInfo'],
        'orderIds': selected.map((o) => o.id).toList(),
      });
    } catch (e) {
      if (mounted) setState(() => _error = operationErrorMessage(e));
    }
  }

  Future<void> _runAction(
    CompanyRecord run,
    String action, {
    Map<String, Object?>? stop,
    CompanyRecord? order,
  }) async {
    final values = <String, Object?>{
      'runId': run.id,
      'expectedRevision': run.revision,
    };
    if (stop != null) values['stopId'] = stop['id'];
    if (action == 'dispatchRun') {
      if (!await _confirm(
        'Dispatch delivery?',
        '${run.string('driverName')} · ${run.records('stops').length} stops\nConfirm that the rider has the packages. This commits warehouse stock to transit.',
      )) {
        return;
      }
    } else if (action == 'cancelRun') {
      final f = await _form('cancel-run:${run.id}', 'Cancel draft delivery', [
        _text('reason', 'Reason'),
      ]);
      if (f == null) return;
      values.addAll(f);
    } else if (action == 'receiveReturns') {
      final items = (stop!['items'] as List)
          .map((l) => Map<String, Object?>.from(l as Map))
          .where((l) => (l['quantityReturned'] as int) > 0)
          .toList();
      final f = await _form(
        'returns:${stop['id']}',
        'Receive returned goods',
        [
          _text('reference', 'Return receipt reference'),
          for (final l in items)
            _count(
              'q:${l['productId']}',
              '${l['productName']} · actual returned ${l['unitName']}',
              initial: l['quantityReturned'] as int,
            ),
          _text('reason', 'Reason if quantities differ', optional: true),
        ],
        explanation:
            'Received returns enter quarantine. The owner releases stock after inspection.',
      );
      if (f == null) return;
      values.addAll({
        'reference': f['reference'],
        'reason': f['reason'],
        'items': items
            .map(
              (l) => {
                'productId': l['productId'],
                'quantity': f['q:${l['productId']}'],
              },
            )
            .toList(),
      });
    } else if (action == 'confirmRemittance') {
      final expected = run
          .records('stops')
          .fold<int>(
            0,
            (s, l) =>
                s +
                ((l['proof'] as Map?)?['cashCollectedCentavos'] as int? ?? 0),
          );
      final f = await _form(
        'remit:${run.id}',
        'Receive rider remittance',
        [
          _money('amountCentavos', 'Cash actually received', initial: expected),
          _text('reason', 'Reason if amount differs', optional: true),
        ],
        explanation:
            'Expected cash: ${_peso(expected)}. Recording collection does not prove warehouse remittance.',
      );
      if (f == null) return;
      values.addAll(f);
    } else if (action == 'resolveReceipt' || action == 'resolveReturns') {
      final f = await _form(
        'resolve:${order?.id ?? stop?['id']}',
        'Record discrepancy resolution',
        [_text('reason', 'Agreed outcome and reference')],
        explanation:
            'This records the outcome without inventing stock or payment changes. Record any correction separately.',
      );
      if (f == null) return;
      values.addAll(f);
      if (order != null) values['orderId'] = order.id;
    }
    await _mutate(action, values);
  }

  String _riderProgressKey(CompanyRecord run, Map<String, Object?> stop) =>
      'rider-progress:${run.id}:${stop['id']}';

  Future<Map<String, Object?>?> _loadRiderStopProgress(
    CompanyRecord run,
    Map<String, Object?> stop,
  ) async {
    try {
      return await _local!.draft(_riderProgressKey(run, stop));
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
      return null;
    }
  }

  Future<bool> _saveRiderStopProgress(
    CompanyRecord run,
    Map<String, Object?> stop,
    Map<String, Object?> progress,
  ) async {
    try {
      await _local!.saveDraft(_riderProgressKey(run, stop), progress);
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
      return false;
    }
  }

  Future<bool> _proof(
    CompanyRecord run,
    Map<String, Object?> stop, [
    Map<String, Object?>? delivery,
  ]) async {
    if (_denied || !_savingTargets.add(run.id)) return false;
    var saved = false;
    try {
      await _track(() async {
        saved = await _proofNow(run, stop, delivery);
      });
    } finally {
      _savingTargets.remove(run.id);
      if (_current) setState(() {});
    }
    return saved;
  }

  Future<bool> _proofNow(
    CompanyRecord run,
    Map<String, Object?> stop, [
    Map<String, Object?>? delivery,
  ]) async {
    _offlineProofAllowed =
        !_denied && await _local!.offlineAllowed(await _clock());
    if (!_offlineProofAllowed) {
      setState(
        () => _error = 'Refresh delivery access online before recording work.',
      );
      return false;
    }
    if ((await _local!.pending()).any(
      (o) =>
          o['status'] == 'blocked' &&
          (jsonDecode(o['payload'] as String) as Map)['runId'] == run.id,
    )) {
      setState(
        () => _error =
            'A previous record needs review. Keep it and contact warehouse operations.',
      );
      return false;
    }
    final items = (stop['items'] as List)
        .map((v) => Map<String, Object?>.from(v as Map))
        .toList();
    final orderValue = items.fold<int>(
      0,
      (sum, item) =>
          sum +
          (item['quantityOrdered'] as int) * (item['unitCostCentavos'] as int),
    );
    final paymentMethod = companyDeliveryPaymentMethod(stop);
    final dueValue = stop['amountDueCentavos'];
    final int? amountDueForFullOrder = dueValue is num
        ? dueValue.toInt().clamp(0, orderValue)
        : null;
    if (paymentMethod == 'cashOnDelivery' && amountDueForFullOrder == null) {
      if (mounted) {
        setState(
          () => _error =
              'COD amount is unavailable. Contact warehouse operations before collecting cash.',
        );
      }
      return false;
    }
    final alreadyPaid = amountDueForFullOrder == null
        ? 0
        : orderValue - amountDueForFullOrder;
    late Map<String, Object?> form;
    late List<Map<String, Object?>> updated;
    if (delivery == null) {
      final fields = <_Field>[
        for (final line in items) ...[
          _count(
            'd:${line['productId']}',
            '${line['productName']} · delivered ${line['unitName']} · ${_peso(line['unitCostCentavos'] as int)} each',
            initial: line['quantityOrdered'] as int,
          ),
          _count('r:${line['productId']}', 'Returned ${line['unitName']}'),
          _text(
            'reason:${line['productId']}',
            'Return / failure reason',
            optional: true,
          ),
        ],
        _text('recipientName', 'Recipient name'),
        _text('recipientRole', 'Recipient role', initial: 'Store Owner'),
        if (paymentMethod == 'cashOnDelivery')
          _money('cashCollectedCentavos', 'Cash actually collected'),
        _text(
          'notes',
          paymentMethod == 'cashOnDelivery'
              ? 'Payment issue / delivery notes'
              : 'Delivery notes',
          optional: true,
        ),
      ];
      final paymentExplanation = switch (paymentMethod) {
        'cashOnDelivery' =>
          'Cash due if all units are delivered: ${_peso(amountDueForFullOrder!)}. Record only cash actually collected; remittance is recorded separately.',
        'qr' =>
          amountDueForFullOrder == null
              ? 'QR payment status is unavailable. Do not collect cash for this order.'
              : amountDueForFullOrder == 0
              ? 'QR payment is confirmed. Do not collect cash for this order.'
              : 'QR payment is awaiting company confirmation for the remaining ${_peso(amountDueForFullOrder)}. Do not collect cash for this order.',
        _ =>
          'Payment method is unavailable. Do not collect cash for this order.',
      };
      final legacyForm = await _form(
        'proof:${stop['id']}',
        'Record delivery',
        fields,
        action: 'Review delivery',
        explanation:
            'Agreed prices are shown beside each product. The amount due updates to match delivered quantities. $paymentExplanation',
      );
      if (legacyForm == null) return false;
      form = legacyForm;
      updated = items
          .map(
            (line) => {
              ...line,
              'quantityDelivered': form['d:${line['productId']}'],
              'quantityReturned': form['r:${line['productId']}'],
              'returnReason': form['reason:${line['productId']}'],
            },
          )
          .toList();
    } else {
      form = delivery;
      final editedLines = (delivery['items'] as List? ?? const [])
          .whereType<Map>()
          .map((line) => Map<String, Object?>.from(line))
          .toList();
      final editsByProduct = {
        for (final line in editedLines) line['productId']?.toString(): line,
      };
      updated = items.map((line) {
        final edit = editsByProduct[line['productId']?.toString()];
        return {
          ...line,
          'quantityDelivered': edit?['quantityDelivered'],
          'quantityReturned': edit?['quantityReturned'],
          'returnReason': edit?['returnReason'],
        };
      }).toList();
    }
    if (updated.any(
      (l) =>
          ((l['quantityDelivered'] as num?)?.toInt() ?? -1) +
                  ((l['quantityReturned'] as num?)?.toInt() ?? -1) !=
              (l['quantityOrdered'] as num?)?.toInt() ||
          (((l['quantityReturned'] as num?)?.toInt() ?? 0) > 0 &&
              (l['returnReason'] as String? ?? '').trim().isEmpty),
    )) {
      setState(
        () => _error =
            'Account for all units and give a reason for each returned item.',
      );
      return false;
    }
    final value = updated.fold<int>(
      0,
      (s, l) =>
          s +
          ((l['quantityDelivered'] as num?)?.toInt() ?? 0) *
              (l['unitCostCentavos'] as int),
    );
    final int? amountDue = amountDueForFullOrder == null
        ? null
        : value > alreadyPaid
        ? value - alreadyPaid
        : 0;
    int cashCollected;
    if (delivery == null) {
      cashCollected = paymentMethod == 'cashOnDelivery'
          ? (form['cashCollectedCentavos'] as num?)?.toInt() ?? 0
          : 0;
    } else {
      final text = delivery['cashCollectedText']?.toString().trim() ?? '';
      if (text.isEmpty) {
        cashCollected = 0;
      } else if (!RegExp(r'^[0-9]+([.][0-9]{1,2})?$').hasMatch(text)) {
        if (mounted) setState(() => _error = 'Enter a valid cash amount.');
        return false;
      } else {
        final parts = text.split('.');
        final pesos = int.tryParse(parts.first);
        if (pesos == null) {
          if (mounted) setState(() => _error = 'Enter a valid cash amount.');
          return false;
        }
        cashCollected =
            pesos * 100 +
            (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
      }
    }
    final paymentIssue = delivery?['paymentIssue']?.toString().trim() ?? '';
    final deliveryNotes = form['notes']?.toString().trim() ?? '';
    final recipientName = form['recipientName']?.toString().trim() ?? '';
    final recipientRole = form['recipientRole']?.toString().trim() ?? '';
    if (recipientName.isEmpty || recipientRole.isEmpty) {
      if (mounted) setState(() => _error = 'Add the recipient name and role.');
      return false;
    }
    if (paymentMethod != 'cashOnDelivery' && cashCollected != 0) {
      if (mounted) {
        setState(() => _error = 'Cash can only be recorded for COD orders.');
      }
      return false;
    }
    if (amountDue != null && cashCollected > amountDue) {
      setState(
        () => _error =
            'Cash collected exceeds the amount due of ${_peso(amountDue)}.',
      );
      return false;
    }
    if (paymentMethod == 'cashOnDelivery' &&
        amountDue != null &&
        cashCollected < amountDue &&
        paymentIssue.isEmpty &&
        deliveryNotes.isEmpty) {
      if (mounted) {
        setState(
          () => _error = 'Add a note explaining the remaining COD balance.',
        );
      }
      return false;
    }
    final notes = [
      if (paymentIssue.isNotEmpty) 'Payment issue: $paymentIssue',
      if (deliveryNotes.isNotEmpty) deliveryNotes,
    ].join('\n');
    final alreadyPaidSummary = amountDueForFullOrder == null
        ? 'Already paid: unavailable'
        : 'Already paid: ${_peso(alreadyPaid)}';
    final amountDueSummary = amountDue == null
        ? 'Amount due now: unavailable'
        : 'Amount due now: ${_peso(amountDue)}';
    final remainingSummary = amountDue == null
        ? 'Remaining balance: unavailable'
        : 'Remaining balance: ${_peso(amountDue - cashCollected)}';
    final reviewSummary = [
      'Delivered product value: ${_peso(value)}',
      alreadyPaidSummary,
      amountDueSummary,
      'Cash collected: ${_peso(cashCollected)}',
      remainingSummary,
      'The store owner still confirms their actual receipt.',
    ].join('\n');
    if (!mounted || !await _confirm('Review delivery amounts', reviewSummary)) {
      return false;
    }
    // A form can stay open across a background access denial or expiry.
    // Check authority again at the durable commit boundary.
    if (!_current || _denied || !await _local!.offlineAllowed(await _clock())) {
      if (mounted) {
        setState(
          () =>
              _error = 'Refresh delivery access online before recording work.',
        );
      }
      return false;
    }
    final operationId = const Uuid().v4();
    final payload = {
      'runId': run.id,
      'stopId': stop['id'],
      'expectedRevision': run.revision,
      'items': updated,
      'recipientName': recipientName,
      'recipientRole': recipientRole,
      'cashCollectedCentavos': cashCollected,
      'notes': notes,
    };
    final stops = run
        .records('stops')
        .map(
          (s) => s['id'] == stop['id']
              ? {
                  ...s,
                  'items': updated,
                  'status':
                      updated.every(
                        (l) => (l['quantityReturned'] as num?)?.toInt() == 0,
                      )
                      ? 'delivered'
                      : updated.every(
                          (l) => (l['quantityDelivered'] as num?)?.toInt() == 0,
                        )
                      ? 'failed'
                      : 'partiallyDelivered',
                  'proof': {
                    'id': operationId,
                    'cashCollectedCentavos': cashCollected,
                    'recipientName': recipientName,
                  },
                  'localPending': true,
                }
              : s,
        )
        .toList();
    try {
      await _local!.queueProof(operationId, payload, {
        ...run.data,
        'revision': run.revision + 1,
        'stops': stops,
      });
      await _local!.clearDraft('form:proof:${stop['id']}');
      await _local!.clearDraft(_riderProgressKey(run, stop));
      await _overlayPending();
      if (_current) setState(() {});
      _showNotice('Delivery saved locally · Sync pending');
      unawaited(_uploadProofs());
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = operationErrorMessage(e));
      return false;
    }
  }

  @override
  void dispose() {
    _riderRunRefreshTimer?.cancel();
    _orderingCatalog?.dispose();
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_display);
    if (widget.controller == null) _controller?.dispose();
    _scroll.dispose();
    _orderSearchController.dispose();
    _stockSearchController.dispose();
    _deliverySearchController.dispose();
    _orderSearchFocus.dispose();
    // Let an in-flight proof finish before closing its durable storage.
    unawaited(_closeStorage());
    super.dispose();
  }

  Future<void> _closeStorage() async {
    await _proofWork;
    while (_work.isNotEmpty) {
      await Future.wait(
        _work.toList().map((work) => work.catchError((Object _) {})),
      );
    }
    await _local?.close();
  }

  String get _selectedWarehouseName {
    for (final warehouse in _warehouses) {
      if (warehouse.id == _warehouse) return warehouse.string('name');
    }
    return 'Choose warehouse';
  }

  AppBar _ordersAppBar() => AppBar(
    automaticallyImplyLeading: false,
    titleSpacing: SariSupplySpacing.md,
    toolbarHeight: MediaQuery.textScalerOf(
      context,
    ).scale(64).clamp(64, 128).toDouble(),
    backgroundColor: SariSupplyColors.paper,
    foregroundColor: SariSupplyColors.ink950,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    title: Row(
      children: [
        const SariSupplySymbol(size: 28),
        const SizedBox(width: SariSupplySpacing.sm),
        Expanded(
          child: Semantics(
            button: true,
            enabled: _warehouses.isNotEmpty && !_saving && !_denied,
            label:
                'Switch warehouse. Current warehouse: $_selectedWarehouseName',
            child: InkWell(
              onTap: _warehouses.isEmpty || _saving || _denied
                  ? null
                  : _showWarehousePicker,
              borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Warehouse',
                            style: SariSupplyTypography.caption.copyWith(
                              color: SariSupplyColors.ink600,
                            ),
                          ),
                          Text(
                            _selectedWarehouseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SariSupplyTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SariSupplySpacing.xxs),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: SariSupplyColors.ink600,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    actions: [_profileMenu()],
  );

  Widget _profileMenu() {
    final user = FirebaseAuth.instance.currentUser;
    final identity =
        (user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!.trim()
            : user?.email?.trim()) ??
        '';
    final initial = identity.isEmpty
        ? 'A'
        : identity.substring(0, 1).toUpperCase();
    return PopupMenuButton<String>(
      tooltip: 'Account options',
      enabled: !_saving,
      onSelected: (value) {
        if (value == 'workspace') widget.onExit?.call();
        if (value == 'signOut' && widget.onSignOut != null) {
          unawaited(widget.onSignOut!.call());
        }
      },
      itemBuilder: (context) => [
        if (widget.onExit != null)
          const PopupMenuItem(
            value: 'workspace',
            child: Text('Choose workspace'),
          ),
        if (widget.onSignOut != null)
          const PopupMenuItem(value: 'signOut', child: Text('Sign out')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: SariSupplyColors.canvas,
              foregroundColor: SariSupplyColors.ink950,
              child: Text(initial, style: SariSupplyTypography.bodyLarge),
            ),
            const SizedBox(width: SariSupplySpacing.xxs),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: SariSupplyColors.ink600,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWarehousePicker() async {
    if (_warehouses.isEmpty || _saving || _denied) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SariSupplySpacing.md,
            SariSupplySpacing.sm,
            SariSupplySpacing.md,
            SariSupplySpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: SariSupplySpacing.sm),
                child: Text(
                  'Switch warehouse',
                  style: SariSupplyTypography.sectionHeading,
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _warehouses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final warehouse = _warehouses[index];
                    final isSelected = warehouse.id == _warehouse;
                    final address = warehouse.string('address');
                    return ListTile(
                      minTileHeight: 56,
                      contentPadding: EdgeInsets.zero,
                      title: Text(warehouse.string('name')),
                      subtitle: address.isEmpty ? null : Text(address),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check,
                              color: SariSupplyColors.orange700,
                            )
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(warehouse.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null || selected == _warehouse) return;
    if (_scroll.hasClients) {
      _scrollPositions['$_warehouse:$_tab'] = _scroll.offset;
    }
    setState(() => _warehouse = selected);
    _display();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(
          (_scrollPositions['$_warehouse:$_tab'] ?? 0).clamp(
            0,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
    });
    unawaited(_refresh(force: false, kinds: {_visibleKind}));
  }

  Future<void> _showOrderFilters() async {
    var unpaidOnly = _filterUnpaidOrders;
    var receiptReviewOnly = _filterReceiptReview;
    var includeOtherStatuses = _includeOtherOrderStatuses;
    final selection = await showModalBottomSheet<_OrderFilterSelection>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SariSupplySpacing.md,
              SariSupplySpacing.sm,
              SariSupplySpacing.md,
              SariSupplySpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: SariSupplySpacing.sm),
                  child: Text(
                    'Filter orders',
                    style: SariSupplyTypography.sectionHeading,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Payment due'),
                  value: unpaidOnly,
                  onChanged: (value) =>
                      setSheetState(() => unpaidOnly = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Receipt needs review'),
                  value: receiptReviewOnly,
                  onChanged: (value) =>
                      setSheetState(() => receiptReviewOnly = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include other statuses'),
                  subtitle: const Text('Cancelled, rejected, and ungrouped'),
                  value: includeOtherStatuses,
                  onChanged: (value) => setSheetState(
                    () => includeOtherStatuses = value ?? false,
                  ),
                ),
                const SizedBox(height: SariSupplySpacing.xs),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(const _OrderFilterSelection()),
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(
                        _OrderFilterSelection(
                          unpaidOnly: unpaidOnly,
                          receiptReviewOnly: receiptReviewOnly,
                          includeOtherStatuses: includeOtherStatuses,
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _filterUnpaidOrders = selection.unpaidOnly;
      _filterReceiptReview = selection.receiptReviewOnly;
      _includeOtherOrderStatuses = selection.includeOtherStatuses;
    });
  }

  Future<void> _showDeliveryFilters() async {
    var needsReview = _deliveryNeedsReviewOnly;
    final selection = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SariSupplySpacing.md,
              SariSupplySpacing.sm,
              SariSupplySpacing.md,
              SariSupplySpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: SariSupplySpacing.sm),
                  child: Text(
                    'Filter delivery runs',
                    style: SariSupplyTypography.sectionHeading,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Needs review'),
                  subtitle: const Text('Returns or rider remittance'),
                  value: needsReview,
                  onChanged: (value) =>
                      setSheetState(() => needsReview = value ?? false),
                ),
                const SizedBox(height: SariSupplySpacing.xs),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(needsReview),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selection == null || !mounted) return;
    setState(() => _deliveryNeedsReviewOnly = selection);
  }

  List<CompanyRecord> get _visibleOrders {
    final query = _orderSearchController.text;
    return _orders.where((order) {
      final group = companyOrderQueueTab(order);
      final matchesGroup =
          group == _selectedOrderTab ||
          (_includeOtherOrderStatuses && group == null);
      return matchesGroup &&
          companyOrderMatchesSearch(order, query) &&
          (!_filterUnpaidOrders || _balance(order) > 0) &&
          (!_filterReceiptReview ||
              order.string('receiptStatus') == 'needsReview');
    }).toList();
  }

  Widget _ordersHeader() {
    final counts = {
      for (final tab in CompanyOrderQueueTab.values)
        tab: _orders
            .where((order) => companyOrderQueueTab(order) == tab)
            .length,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Orders', style: SariSupplyTypography.sectionHeading),
            ),
            IconButton(
              tooltip: _orderSearchOpen
                  ? 'Close order search'
                  : 'Search orders',
              onPressed: () {
                setState(() {
                  _orderSearchOpen = !_orderSearchOpen;
                  if (!_orderSearchOpen) _orderSearchController.clear();
                });
                if (_orderSearchOpen) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _orderSearchFocus.requestFocus();
                  });
                }
              },
              icon: Icon(
                _orderSearchOpen ? Icons.close : Icons.search,
                size: 24,
                color: SariSupplyColors.ink950,
              ),
            ),
            IconButton(
              tooltip: _hasOrderFilters ? 'Filters applied' : 'Filter orders',
              onPressed: _showOrderFilters,
              icon: Icon(
                Icons.tune,
                size: 24,
                color: _hasOrderFilters
                    ? SariSupplyColors.orange700
                    : SariSupplyColors.ink950,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Order actions',
              enabled: !_denied && !_loading && _warehouse != null,
              icon: const Icon(Icons.more_vert),
              onSelected: (_) => _openItemRequests(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'requests',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.playlist_add),
                    title: Text('Item requests'),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_orderSearchOpen) ...[
          const SizedBox(height: SariSupplySpacing.xs),
          TextField(
            controller: _orderSearchController,
            focusNode: _orderSearchFocus,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Store, order ID, or location',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _orderSearchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
        const SizedBox(height: SariSupplySpacing.sm),
        CompanyQueueTabs(
          tabs: [
            for (final tab in CompanyOrderQueueTab.values)
              _orderTabButton(tab, counts[tab] ?? 0),
          ],
        ),
        const Divider(height: 1),
      ],
    );
  }

  Map<_DeliveryQueueTab, int> get _deliveryCounts => {
    for (final tab in _DeliveryQueueTab.values)
      tab: _runs.where((run) => _deliveryQueueFor(run) == tab).length,
  };

  _DeliveryQueueTab _deliveryQueueFor(CompanyRecord run) =>
      switch (companyDeliveryQueue(run)) {
        CompanyDeliveryQueue.drafts => _DeliveryQueueTab.unassigned,
        CompanyDeliveryQueue.onRoute => _DeliveryQueueTab.active,
        CompanyDeliveryQueue.history => _DeliveryQueueTab.completed,
      };

  Widget _deliveryHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final title = Text(
            'Deliveries',
            style: SariSupplyTypography.sectionHeading,
          );
          final action = TextButton.icon(
            onPressed: _warehouse == null || _denied || _loading
                ? null
                : _newRun,
            style: TextButton.styleFrom(
              foregroundColor: SariSupplyColors.orange600,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.add, size: 22),
            label: const Text('New delivery'),
          );
          if (constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, action],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              action,
            ],
          );
        },
      ),
      const SizedBox(height: SariSupplySpacing.sm),
      TextField(
        controller: _deliverySearchController,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search run ID, driver or location',
          prefixIcon: const Icon(Icons.search, color: SariSupplyColors.ink600),
          suffixIcon: IconButton(
            tooltip: _deliveryNeedsReviewOnly
                ? 'Delivery filters applied'
                : 'Filter delivery runs',
            onPressed: _showDeliveryFilters,
            icon: Icon(
              Icons.tune,
              color: _deliveryNeedsReviewOnly
                  ? SariSupplyColors.orange600
                  : SariSupplyColors.ink600,
            ),
          ),
          filled: true,
          fillColor: SariSupplyColors.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SariSupplySpacing.md,
            vertical: SariSupplySpacing.sm,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SariSupplyRadii.md),
            borderSide: const BorderSide(color: SariSupplyColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SariSupplyRadii.md),
            borderSide: const BorderSide(color: SariSupplyColors.orange600),
          ),
        ),
      ),
      const SizedBox(height: SariSupplySpacing.sm),
      CompanyQueueTabs(
        tabs: [
          for (final tab in _DeliveryQueueTab.values)
            _deliveryTabButton(tab, _deliveryCounts[tab] ?? 0),
        ],
      ),
      const Divider(height: 1),
    ],
  );

  Widget _deliveryTabButton(_DeliveryQueueTab tab, int count) {
    final label = switch (tab) {
      _DeliveryQueueTab.unassigned => 'Drafts',
      _DeliveryQueueTab.active => 'On route',
      _DeliveryQueueTab.completed => 'History',
    };
    return CompanyQueueTab(
      selected: tab == _selectedDeliveryTab,
      label: label,
      count: count,
      onTap: () => setState(() => _selectedDeliveryTab = tab),
    );
  }

  bool get _hasOrderFilters =>
      _filterUnpaidOrders || _filterReceiptReview || _includeOtherOrderStatuses;

  Widget _orderTabButton(CompanyOrderQueueTab tab, int count) =>
      CompanyQueueTab(
        selected: tab == _selectedOrderTab,
        label: tab.label,
        count: count,
        onTap: () => setState(() => _selectedOrderTab = tab),
      );

  Widget _orderQueueSliver() {
    if (_loading && _orders.isEmpty && _warehouse != null) {
      return SliverList.builder(
        itemCount: 3,
        itemBuilder: (context, index) => _orderSkeletonRow(),
      );
    }
    if (_orders.isEmpty && (_error != null || _warehouse == null)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final orders = _visibleOrders;
    if (orders.isEmpty) {
      final query = _orderSearchController.text.trim();
      final message = query.isNotEmpty
          ? 'No matching orders'
          : _hasOrderFilters
          ? 'No orders match these filters'
          : 'No ${_selectedOrderTab.label.toLowerCase()} orders';
      final nextTabs =
          [
            CompanyOrderQueueTab.ready,
            CompanyOrderQueueTab.onRoute,
            CompanyOrderQueueTab.accepted,
            CompanyOrderQueueTab.awaiting,
            CompanyOrderQueueTab.completed,
          ].where(
            (tab) =>
                tab != _selectedOrderTab &&
                _orders.any((order) => companyOrderQueueTab(order) == tab),
          );
      final nextTab = nextTabs.isEmpty ? null : nextTabs.first;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: CompanyOrderQueueEmptyState(
          message: message,
          explanation: query.isNotEmpty || _hasOrderFilters
              ? 'Try another search or clear the filters to see this queue.'
              : nextTab != null
              ? 'Other queues have orders you can work on.'
              : 'New store orders will appear here. Pull down to refresh.',
          action: query.isNotEmpty || _hasOrderFilters
              ? OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _orderSearchController.clear();
                    _filterUnpaidOrders = false;
                    _filterReceiptReview = false;
                    _includeOtherOrderStatuses = false;
                  }),
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Clear search and filters'),
                )
              : nextTab != null
              ? FilledButton.icon(
                  onPressed: () => setState(() => _selectedOrderTab = nextTab),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('View ${nextTab.label.toLowerCase()} orders'),
                )
              : null,
        ),
      );
    }
    return SliverList.builder(
      itemCount: orders.length,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final index = orders.indexWhere((order) => order.id == key.value);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) => _warehouseOrderCard(orders[index]),
    );
  }

  Widget _orderSkeletonRow() => Padding(
    padding: const EdgeInsets.symmetric(vertical: SariSupplySpacing.lg),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBar(150, 20),
                  const SizedBox(height: SariSupplySpacing.sm),
                  _skeletonBar(120, 14),
                  const SizedBox(height: SariSupplySpacing.md),
                  _skeletonBar(96, 14),
                  const SizedBox(height: SariSupplySpacing.xs),
                  _skeletonBar(170, 14),
                ],
              ),
            ),
            const SizedBox(width: SariSupplySpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _skeletonBar(84, 20),
                const SizedBox(height: 12),
                _skeletonBar(76, 28),
              ],
            ),
          ],
        ),
        const SizedBox(height: SariSupplySpacing.lg),
        const Divider(height: 1),
      ],
    ),
  );

  Widget _skeletonBar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: SariSupplyColors.ink50,
      borderRadius: BorderRadius.circular(SariSupplyRadii.xs),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_rider) {
      return CompanyRiderRoute(
        companyName: widget.title,
        runs: _denied ? const [] : _runs,
        loading: _loading,
        busy:
            _refreshing ||
            _saving ||
            _syncingProofs ||
            _savingTargets.isNotEmpty,
        actionsEnabled: !_denied,
        error: _error,
        notice:
            _message ??
            (_pendingRuns.isNotEmpty
                ? 'Saved on this phone · Waiting to sync'
                : _cached
                ? 'Offline · showing saved delivery runs'
                : null),
        onRefresh: () => _refresh(),
        onRetrySync: _denied ? null : () => _uploadProofs(),
        onLoadMore: !_denied && _pages['runs']?.hasMore == true
            ? () => _more('runs')
            : null,
        onDirections: (stop) => _maps(stop),
        onProof: (run, stop) {
          unawaited(_proof(run, stop).then<void>((_) {}));
        },
        onRecordProof: (run, stop) => _proof(run, stop),
        onRecordDelivery: (run, stop, delivery) => _proof(run, stop, delivery),
        onLoadStopProgress: _loadRiderStopProgress,
        onSaveStopProgress: _saveRiderStopProgress,
        onSignOut: widget.onSignOut,
        onExit: widget.onExit,
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final kind = _rider
        ? 'runs'
        : _store
        ? 'orders'
        : _tab == 0
        ? 'orders'
        : _tab == 1
        ? 'products'
        : 'runs';
    return Scaffold(
      backgroundColor: _redesignedStock || _redesignedDeliveries
          ? SariSupplyColors.paper
          : null,
      appBar: _operationsRedesignHeader
          ? _ordersAppBar()
          : sariSupplyTaskAppBar(
              context,
              title: _rider
                  ? 'Deliveries'
                  : _store
                  ? 'Company orders'
                  : widget.title,
              actions: [
                IconButton(
                  onPressed: _refreshing || _denied ? null : () => _refresh(),
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
                if (widget.onSignOut != null)
                  IconButton(
                    onPressed: _saving ? null : widget.onSignOut,
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout),
                  ),
                if (widget.onExit != null)
                  IconButton(
                    onPressed: _saving ? null : widget.onExit,
                    tooltip: 'Choose workspace',
                    icon: const Icon(Icons.swap_horiz),
                  ),
              ],
            ),
      bottomNavigationBar: _store || _rider
          ? null
          : CompanyNavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) async {
                var destination = i;
                if (i == 3) {
                  if (widget.onAdministration != null) {
                    final selected = await widget.onAdministration!();
                    if (!mounted) return;
                    _controller?.invalidate('warehouses');
                    _controller?.invalidate('paymentInstructions');
                    if (selected == null) {
                      await _refresh(force: false);
                      return;
                    }
                    destination = selected;
                  } else {
                    await widget.onMore?.call();
                    if (mounted) {
                      _controller?.invalidate('warehouses');
                      _controller?.invalidate('paymentInstructions');
                      await _refresh(force: false);
                    }
                    return;
                  }
                }
                if (!mounted || destination < 0 || destination > 2) return;
                if (_scroll.hasClients) {
                  _scrollPositions['$_warehouse:$_tab'] = _scroll.offset;
                }
                setState(() => _tab = destination);
                _display();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _scroll.hasClients) {
                    _scroll.jumpTo(
                      (_scrollPositions['$_warehouse:$_tab'] ?? 0).clamp(
                        0,
                        _scroll.position.maxScrollExtent,
                      ),
                    );
                  }
                });
                unawaited(_refresh(force: false));
              },
            ),
      body: RefreshIndicator(
        onRefresh: () => _redesignedOrders
            ? _refresh(force: true, kinds: {'orders'})
            : _redesignedStock
            ? _refresh(force: true, kinds: {'products'})
            : _refresh(),
        notificationPredicate: (notification) =>
            (_store || _operationsRedesignHeader) && notification.depth == 0,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: CustomScrollView(
                key: PageStorageKey('company:$_warehouse:$_tab'),
                controller: _scroll,
                physics: _store || _operationsRedesignHeader
                    ? const AlwaysScrollableScrollPhysics()
                    : null,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(width < 600 ? 16 : 24),
                    sliver: SliverList.list(
                      children: [
                        if (_loading ||
                            _refreshing ||
                            _saving ||
                            _syncingProofs)
                          const LinearProgressIndicator(),
                        if (!_store && !_rider && !_operationsRedesignHeader)
                          DropdownButtonFormField<String>(
                            initialValue: _warehouse,
                            decoration: const InputDecoration(
                              labelText: 'Warehouse',
                            ),
                            items: _warehouses
                                .map(
                                  (w) => DropdownMenuItem(
                                    value: w.id,
                                    child: Text(w.string('name')),
                                  ),
                                )
                                .toList(),
                            onChanged: _saving || _denied
                                ? null
                                : (id) {
                                    if (_scroll.hasClients) {
                                      _scrollPositions['$_warehouse:$_tab'] =
                                          _scroll.offset;
                                    }
                                    setState(() => _warehouse = id);
                                    _display();
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      if (mounted && _scroll.hasClients) {
                                        _scroll.jumpTo(
                                          (_scrollPositions['$_warehouse:$_tab'] ??
                                                  0)
                                              .clamp(
                                                0,
                                                _scroll
                                                    .position
                                                    .maxScrollExtent,
                                              ),
                                        );
                                      }
                                    });
                                    unawaited(_refresh(force: false));
                                  },
                          ),
                        if (_cached && _redesignedOrders)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: SariSupplySpacing.xs,
                            ),
                            child: Text(
                              'Offline · showing saved orders${_savedAt == null ? '' : ' · ${TimeOfDay.fromDateTime(_savedAt!.toLocal()).format(context)}'}',
                              style: SariSupplyTypography.caption,
                            ),
                          ),
                        if (_cached && !_redesignedOrders)
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              _redesignedDeliveries
                                  ? 'Offline · showing saved delivery runs${_savedAt == null ? '' : ' · ${TimeOfDay.fromDateTime(_savedAt!.toLocal()).format(context)}'}'
                                  : 'Last saved data${_savedAt == null ? '' : ' · ${MaterialLocalizations.of(context).formatShortDate(_savedAt!.toLocal())} ${TimeOfDay.fromDateTime(_savedAt!.toLocal()).format(context)}'} · Refresh online to confirm current status',
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SariSupplyStatus(
                              message: _error!,
                              error: true,
                            ),
                          ),
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SariSupplyStatus(message: _message!),
                          ),
                        if (!_operationsRedesignHeader)
                          const SizedBox(height: 16),
                        if (_store) _storeOrdersHeader(),
                        if (_redesignedOrders) _ordersHeader(),
                        if (!_store &&
                            !_rider &&
                            _tab == 0 &&
                            !_redesignedOrders)
                          _header('Orders', null, null),
                        if (!_store && !_rider && _tab == 1) ...[
                          if (_redesignedStock)
                            _stockHeader()
                          else
                            _header(
                              'Warehouse stock',
                              _owner ? 'Add product' : null,
                              _denied || _loading ? null : _product,
                            ),
                        ],
                        if (_redesignedDeliveries)
                          _deliveryHeader()
                        else if (_rider || (!_store && _tab == 2))
                          _header(
                            'Delivery runs',
                            _rider ? null : 'Assign delivery',
                            _warehouse == null || _denied || _loading
                                ? null
                                : _newRun,
                          ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width < 600 ? 16 : 24,
                    ),
                    sliver: _store
                        ? _storeOrdersSliver()
                        : _redesignedOrders
                        ? _orderQueueSliver()
                        : _redesignedDeliveries
                        ? _deliveryRunSliver()
                        : _recordSliver(kind),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.all(width < 600 ? 16 : 24),
                    sliver: SliverList.list(
                      children: [
                        if (!_loading && _pages[kind]?.hasMore == true)
                          TextButton(
                            onPressed: () => _more(kind),
                            child: const Text('Load more'),
                          ),
                        if (_store && _pages['products']?.hasMore == true)
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => _more('products'),
                            child: const Text(
                              'Load more products for ordering',
                            ),
                          ),
                        if (!_store &&
                            !_rider &&
                            _warehouse == null &&
                            !_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'Choose a warehouse to see its work. Add warehouses under Company.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordSliver(String kind) {
    if (kind == 'products' && _redesignedStock) {
      return _stockRecordSliver();
    }
    final records = kind == 'products'
        ? _products
        : kind == 'orders'
        ? _orders
        : _rider
        ? _runs
              .where(
                (r) =>
                    ['dispatched', 'inTransit', 'completed'].contains(r.status),
              )
              .toList()
        : _runs;
    return SliverList.builder(
      itemCount: records.isEmpty ? (_loading ? 0 : 1) : records.length,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) {
          return null;
        }
        final i = records.indexWhere((r) => r.id == key.value);
        return i < 0 ? null : i;
      },
      itemBuilder: (context, index) {
        if (records.isEmpty) {
          return Text(
            kind == 'orders'
                ? 'No orders in this workspace yet.'
                : kind == 'runs'
                ? 'No delivery runs assigned yet.'
                : 'No products in this workspace yet.',
          );
        }
        final record = records[index];
        return kind == 'products'
            ? _productCard(record)
            : kind == 'orders'
            ? _orderCard(record)
            : _runCard(record);
      },
    );
  }

  List<CompanyRecord> get _visibleDeliveryRuns {
    final query = _deliverySearchController.text.trim().toLowerCase();
    return _runs.where((run) {
      if (_deliveryQueueFor(run) != _selectedDeliveryTab) return false;
      if (_deliveryNeedsReviewOnly && !_deliveryRunNeedsReview(run)) {
        return false;
      }
      if (query.isEmpty) return true;
      final locations = run
          .records('stops')
          .expand(
            (stop) => [
              stop['destinationName']?.toString() ?? '',
              stop['destinationAddress']?.toString() ?? '',
            ],
          )
          .join(' ');
      final searchable =
          '${run.id} ${run.string('driverName')} '
                  '${run.string('vehicleInfo')} $locations'
              .toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  bool _deliveryRunNeedsReview(CompanyRecord run) =>
      run.string('remittanceStatus') == 'needsReview' ||
      run
          .records('stops')
          .any((stop) => stop['returnsStatus'] == 'needsReview');

  Widget _deliveryRunSliver() {
    if ((_loading && _runs.isEmpty) || _warehouse == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (_runs.isEmpty && _error != null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final runs = _visibleDeliveryRuns;
    if (runs.isEmpty) {
      final query = _deliverySearchController.text.trim();
      final message = query.isNotEmpty
          ? 'No matching delivery runs.'
          : _deliveryNeedsReviewOnly
          ? 'No runs need review.'
          : switch (_selectedDeliveryTab) {
              _DeliveryQueueTab.unassigned => 'No draft deliveries.',
              _DeliveryQueueTab.active => 'No deliveries on the road.',
              _DeliveryQueueTab.completed =>
                'No completed or canceled deliveries.',
            };
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: SariSupplySpacing.md),
          child: Text(
            message,
            style: SariSupplyTypography.body.copyWith(
              color: SariSupplyColors.ink600,
            ),
          ),
        ),
      );
    }
    return SliverList.builder(
      itemCount: runs.length,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final index = runs.indexWhere((run) => run.id == key.value);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) => _deliveryRunRow(runs[index]),
    );
  }

  int _deliveryOrderCount(List<Map<String, Object?>> stops) => stops
      .map((stop) {
        final orderId = stop['orderId']?.toString().trim() ?? '';
        return orderId.isNotEmpty
            ? orderId
            : stop['id']?.toString().trim() ?? '';
      })
      .where((id) => id.isNotEmpty)
      .toSet()
      .length;

  String _deliveryRoute(List<Map<String, Object?>> stops) {
    final destinations = stops
        .map((stop) {
          final name = stop['destinationName']?.toString().trim() ?? '';
          return name.isNotEmpty
              ? name
              : stop['destinationAddress']?.toString().trim() ?? '';
        })
        .where((name) => name.isNotEmpty)
        .toList();
    if (destinations.isEmpty) return 'Location unavailable';
    final route = destinations.length == 1
        ? destinations.first
        : '${destinations.first} → ${destinations.last}';
    return stops.length > 2 ? '${stops.length} stops · $route' : route;
  }

  DateTime? _deliveryRunTime(CompanyRecord run) {
    final fields = run.status == 'completed'
        ? ['completedAt', 'startedAt', 'createdAt']
        : run.status == 'draft'
        ? ['createdAt']
        : ['startedAt', 'createdAt'];
    for (final field in fields) {
      final value = run.data[field];
      if (value is int && value > 0) {
        return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
      }
      if (value is num && value > 0) {
        return DateTime.fromMillisecondsSinceEpoch(value.round()).toLocal();
      }
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed.toLocal();
      }
    }
    return null;
  }

  String _deliveryStatusLabel(CompanyRecord run) => switch (run.status) {
    'draft' =>
      run.string('driverId').trim().isEmpty
          ? 'Draft · rider needed'
          : 'Ready to dispatch',
    'dispatched' => 'Dispatched',
    'inTransit' => 'In transit',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => _label(run.status),
  };

  SsStatus _deliveryStatusKind(CompanyRecord run) => switch (run.status) {
    'draft' =>
      run.string('driverId').trim().isEmpty
          ? SsStatus.neutral
          : SsStatus.warning,
    'dispatched' || 'inTransit' => SsStatus.info,
    'completed' => SsStatus.success,
    'cancelled' => SsStatus.neutral,
    'needsReview' => SsStatus.warning,
    _ => SsStatus.neutral,
  };

  Widget _stockHeader() {
    final counts = {
      for (final filter in _StockFilter.values)
        filter: _stockProductsFor(filter, query: '').length,
    };
    return CompanyStockHeader(
      owner: _owner,
      onAddProduct: _denied || _loading || _saving || _cached ? null : _product,
      onReceiveStock:
          _warehouse == null || _loading || _denied || _cached || _saving
          ? null
          : _receiveStock,
      onRefresh: _refreshing || _denied ? null : () => _refresh(),
      loading: _loading,
      searchController: _stockSearchController,
      onSearch: (_) => setState(() {}),
      filters: [
        _stockFilterTab('All', counts[_StockFilter.all] ?? 0, _StockFilter.all),
        _stockFilterTab(
          'Low stock',
          counts[_StockFilter.lowStock] ?? 0,
          _StockFilter.lowStock,
        ),
        _stockFilterTab(
          'Out of stock',
          counts[_StockFilter.outOfStock] ?? 0,
          _StockFilter.outOfStock,
        ),
      ],
      sortControl: PopupMenuButton<_StockSort>(
        tooltip: 'Sort stock',
        onSelected: (sort) => setState(() => _stockSort = sort),
        itemBuilder: (context) => const [
          PopupMenuItem(value: _StockSort.name, child: Text('Sort by name')),
          PopupMenuItem(
            value: _StockSort.available,
            child: Text('Sort by available quantity'),
          ),
          PopupMenuItem(value: _StockSort.price, child: Text('Sort by price')),
        ],
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.tune, color: SariSupplyColors.ink950),
        ),
      ),
    );
  }

  Widget _stockFilterTab(String label, int count, _StockFilter filter) =>
      CompanyQueueTab(
        selected: filter == _selectedStockFilter,
        label: label,
        count: count,
        onTap: () => setState(() => _selectedStockFilter = filter),
      );

  List<CompanyRecord> _stockProductsFor(_StockFilter filter, {String? query}) {
    final needle = (query ?? _stockSearchController.text).trim().toLowerCase();
    final products = _products.where((product) {
      final available = _availableQuantity(product);
      final matchesFilter = switch (filter) {
        _StockFilter.all => true,
        _StockFilter.lowStock => _isLowStock(product, available),
        _StockFilter.outOfStock => available == 0,
      };
      if (!matchesFilter || needle.isEmpty) return matchesFilter;
      final name = product.string('name').toLowerCase();
      final sku = product.string('sku').toLowerCase();
      final barcode = product.data['barcode']?.toString().toLowerCase() ?? '';
      final barcodes = product.data['barcodes'];
      final matchesBarcodeList =
          barcodes is List &&
          barcodes.any(
            (value) => value.toString().toLowerCase().contains(needle),
          );
      return name.contains(needle) ||
          sku.contains(needle) ||
          barcode.contains(needle) ||
          matchesBarcodeList;
    }).toList();

    switch (_stockSort) {
      case _StockSort.name:
        products.sort(
          (a, b) => a
              .string('name')
              .toLowerCase()
              .compareTo(b.string('name').toLowerCase()),
        );
        break;
      case _StockSort.available:
        products.sort(
          (a, b) => _availableQuantity(a).compareTo(_availableQuantity(b)),
        );
        break;
      case _StockSort.price:
        products.sort(
          (a, b) =>
              a.number('priceCentavos').compareTo(b.number('priceCentavos')),
        );
        break;
      case null:
        break;
    }
    return products;
  }

  bool _isLowStock(CompanyRecord product, int available) {
    final projected = product.data['warehouseStock'];
    final stock = projected is Map
        ? Map<String, Object?>.from(projected)
        : null;
    final rawThreshold =
        stock?['lowStockThreshold'] ?? product.data['lowStockThreshold'];
    if (rawThreshold is! num || rawThreshold <= 0 || available == 0) {
      return false;
    }
    return available <= rawThreshold.toInt();
  }

  int _availableQuantity(CompanyRecord product) {
    final projected = product.data['warehouseStock'];
    if (projected is! Map) return 0;
    final stock = Map<String, Object?>.from(projected);
    final physical = (stock['physical'] as num?)?.toInt() ?? 0;
    final reserved = (stock['reserved'] as num?)?.toInt() ?? 0;
    final available = physical - reserved;
    return available < 0 ? 0 : available;
  }

  Widget _stockRecordSliver() {
    if (_warehouse == null || (_loading && _products.isEmpty)) {
      return _warehouse == null
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : SliverList.builder(
              itemCount: 3,
              itemBuilder: (context, index) => _orderSkeletonRow(),
            );
    }
    final products = _stockProductsFor(_selectedStockFilter);
    if (products.isEmpty) {
      final search = _stockSearchController.text.trim();
      final message = search.isNotEmpty
          ? (_pages['products']?.hasMore == true
                ? 'No matching products on loaded pages. Load more to search further.'
                : 'No products match your search.')
          : _selectedStockFilter == _StockFilter.lowStock
          ? 'No low stock products.'
          : _selectedStockFilter == _StockFilter.outOfStock
          ? 'No out-of-stock products.'
          : 'No products in this warehouse yet.';
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: SariSupplySpacing.md),
          child: Text(
            message,
            style: SariSupplyTypography.body.copyWith(
              color: SariSupplyColors.ink600,
            ),
          ),
        ),
      );
    }
    return SliverList.builder(
      itemCount: products.length,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final index = products.indexWhere((product) => product.id == key.value);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) => _stockProductRow(products[index]),
    );
  }

  Widget _stockProductRow(CompanyRecord product) {
    final stockData = product.data['warehouseStock'];
    final stock = stockData is Map
        ? Map<String, Object?>.from(stockData)
        : const <String, Object?>{};
    final available = _availableQuantity(product);
    final sku = product.string('sku');
    final unitPrice =
        '${_peso(product.number('priceCentavos'))} / ${product.string('unit')}';
    final stockCounts =
        'Reserved ${(stock['reserved'] as num?)?.toInt() ?? 0} · '
        'In transit ${(stock['inTransit'] as num?)?.toInt() ?? 0} · '
        'Quarantine ${(stock['quarantined'] as num?)?.toInt() ?? 0}';
    return InkWell(
      key: ValueKey(product.id),
      onTap: () => _showStockProductDetails(product),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: SariSupplyColors.divider, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: SariSupplySpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductThumbnail(
              imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl,
              productName: product.string('name').isEmpty
                  ? 'Product'
                  : product.string('name'),
              size: 48,
            ),
            const SizedBox(width: SariSupplySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.string('name'),
                    style: SariSupplyTypography.cardHeading,
                  ),
                  const SizedBox(height: SariSupplySpacing.xs),
                  Text(
                    '${sku.isEmpty ? 'No SKU' : sku} · $unitPrice',
                    style: SariSupplyTypography.bodyLarge.copyWith(
                      color: SariSupplyColors.ink600,
                    ),
                  ),
                  const SizedBox(height: SariSupplySpacing.xs),
                  Text(
                    stockCounts,
                    style: SariSupplyTypography.body.copyWith(
                      color: SariSupplyColors.ink600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SariSupplySpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64, maxWidth: 104),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$available',
                        style: SariSupplyTypography.moneyLarge,
                      ),
                      const SizedBox(width: SariSupplySpacing.xxs),
                      const Icon(
                        Icons.chevron_right,
                        color: SariSupplyColors.ink600,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: SariSupplySpacing.xxs),
                  if (available == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SariSupplySpacing.xs,
                        vertical: SariSupplySpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE8E8),
                        borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
                      ),
                      child: Text(
                        'Out of stock',
                        style: SariSupplyTypography.caption.copyWith(
                          color: SariSupplyColors.error,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Available',
                      style: SariSupplyTypography.body.copyWith(
                        color: SariSupplyColors.ink600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _receiveStock() async {
    if (_warehouse == null || _denied || _cached || _saving) return;
    final product = await _pickWarehouseStockProduct();
    if (!mounted || product == null) return;
    await _stockAction(product, 'receiveStock');
  }

  Future<CompanyRecord?> _pickWarehouseStockProduct() =>
      Navigator.of(context).push<CompanyRecord>(
        MaterialPageRoute(
          builder: (_) => _ProductPicker(
            onError: _accessFailure,
            initialRecords: _products,
            initialPage: _pages['products'],
            load: (cursor, query) async {
              final warehouseId = _warehouse;
              if (warehouseId == null) {
                throw StateError('Choose a warehouse before receiving stock.');
              }
              if (cursor != null) {
                await _controller!.more('products', warehouseId: warehouseId);
              }
              final state = _controller!.dataset(
                'products',
                warehouseId: warehouseId,
              );
              final needle = query.trim().toLowerCase();
              final records = state.records.where((product) {
                if (needle.isEmpty) return true;
                return product.string('name').toLowerCase().contains(needle) ||
                    product.string('sku').toLowerCase().contains(needle) ||
                    (product.data['barcode']?.toString().toLowerCase() ?? '')
                        .contains(needle);
              }).toList();
              return CompanyPage(
                records: records,
                nextCursor: state.page?.nextCursor,
                hasMore: state.page?.hasMore ?? false,
              );
            },
            company: true,
          ),
        ),
      );

  Future<void> _showStockProductDetails(CompanyRecord product) async {
    final enabled =
        !_denied &&
        !_cached &&
        !_saving &&
        !_savingTargets.contains(product.id) &&
        _warehouse != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: SariSupplyColors.paper,
      builder: (sheetContext) => CompanyStockProductDetails(
        product: product,
        warehouseName: _selectedWarehouseName,
        owner: _owner,
        actionsEnabled: enabled,
        cached: _cached,
        onClose: () => Navigator.pop(sheetContext),
        onAction: (action) => Navigator.pop(sheetContext, action),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'editPrice') {
      await _editPrice(product);
    } else if (action == 'editProduct') {
      await _editProduct(product);
    } else {
      await _stockAction(product, action);
    }
  }

  Widget _header(String title, String? action, VoidCallback? callback) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (action != null)
              FilledButton.icon(
                onPressed: callback,
                icon: const Icon(Icons.add),
                label: Text(action),
              ),
          ],
        ),
      );
  Widget _productCard(CompanyRecord p) {
    final projected = p.data['warehouseStock'];
    final stock = projected is Map
        ? CompanyRecord({...Map<String, Object?>.from(projected), 'id': p.id})
        : null;
    return Card(
      key: ValueKey(p.id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductThumbnail(
                  imageUrl: p.imageUrl.isEmpty ? null : p.imageUrl,
                  productName: p.string('name').isEmpty
                      ? 'Product'
                      : p.string('name'),
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    p.string('name'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_peso(p.number('priceCentavos'))} / ${p.string('unit')}'),
            Text(
              stock == null
                  ? 'Stock not recorded'
                  : 'Available ${stock.number('physical') - stock.number('reserved')} · Reserved ${stock.number('reserved')} · In transit ${stock.number('inTransit')} · Quarantine ${stock.number('quarantined')}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed:
                      _warehouse == null ||
                          _denied ||
                          _cached ||
                          _savingTargets.contains(p.id)
                      ? null
                      : () => _stockAction(p, 'receiveStock'),
                  child: const Text('Receive stock'),
                ),
                if (_owner && stock != null && stock.number('quarantined') > 0)
                  TextButton(
                    onPressed:
                        _denied || _cached || _savingTargets.contains(p.id)
                        ? null
                        : () => _stockAction(p, 'releaseQuarantine'),
                    child: const Text('Release inspected stock'),
                  ),
                if (_owner)
                  TextButton(
                    onPressed:
                        _denied || _cached || _savingTargets.contains(p.id)
                        ? null
                        : () => _editPrice(p),
                    child: const Text('Edit price'),
                  ),
                if (_owner)
                  PopupMenuButton<String>(
                    enabled: !_denied && !_savingTargets.contains(p.id),
                    tooltip: 'Stock corrections',
                    onSelected: (action) => _stockAction(p, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'correctStock',
                        child: Text('Correct physical stock'),
                      ),
                      PopupMenuItem(
                        value: 'writeOffTransit',
                        child: Text('Write off missing transit stock'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPrice(CompanyRecord p) async {
    final f = await _form('price:${p.id}', 'Edit wholesale price', [
      _money(
        'priceCentavos',
        'Price per ${p.string('unit')}',
        initial: p.number('priceCentavos'),
      ),
    ]);
    if (f != null) {
      await _mutate('saveProduct', {
        ...p.data,
        ...f,
        'productId': p.id,
        'expectedRevision': p.revision,
      });
    }
  }

  Widget _warehouseOrderCard(CompanyRecord order) {
    final store = order.string('storeName').trim().isNotEmpty
        ? order.string('storeName')
        : order.string('branchName');
    final createdAt = DateTime.tryParse(order.string('createdAt'));
    final time = createdAt == null
        ? ''
        : '${MaterialLocalizations.of(context).formatShortDate(createdAt.toLocal())} · ${TimeOfDay.fromDateTime(createdAt.toLocal()).format(context)}';
    final status = order.status;
    final needsReview = order.string('receiptStatus') == 'needsReview';
    final completed =
        status == 'completed' ||
        const {'confirmed', 'resolved'}.contains(order.string('receiptStatus'));
    final cancelled = status == 'cancelled' || status == 'rejected';
    final statusColor = needsReview
        ? SariSupplyColors.warning
        : completed
        ? SariSupplyColors.success
        : cancelled
        ? SariSupplyColors.error
        : companyOrderQueueTab(order) == CompanyOrderQueueTab.onRoute
        ? SariSupplyColors.info
        : companyOrderQueueTab(order) == CompanyOrderQueueTab.awaiting
        ? SariSupplyColors.orange700
        : SariSupplyColors.ink600;
    final statusBackgroundColor = needsReview
        ? SariSupplyColors.warning.withValues(alpha: 0.10)
        : completed
        ? SariSupplyColors.success.withValues(alpha: 0.10)
        : cancelled
        ? SariSupplyColors.error.withValues(alpha: 0.10)
        : companyOrderQueueTab(order) == CompanyOrderQueueTab.onRoute
        ? SariSupplyColors.info.withValues(alpha: .1)
        : companyOrderQueueTab(order) == CompanyOrderQueueTab.awaiting
        ? SariSupplyColors.orange50
        : SariSupplyColors.ink50;
    return CompanyOrderQueueRow(
      key: ValueKey(order.id),
      order: order,
      storeName: store,
      orderTime: time,
      amount: _orderAmount(order),
      statusLabel: completed && !needsReview
          ? 'Received'
          : _orderStatusText(order),
      statusColor: statusColor,
      statusBackgroundColor: statusBackgroundColor,
      onOpenDetails: () => _showWarehouseOrderDetails(
        order,
        store,
        completed && !needsReview ? 'Received' : _orderStatusText(order),
      ),
      absorbing: _savingTargets.contains(order.id),
    );
  }

  Future<void> _showWarehouseOrderDetails(
    CompanyRecord order,
    String storeName,
    String statusLabel,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: CompanyOrderDetails(
          order: order,
          storeName: storeName,
          statusLabel: statusLabel,
          totalCentavos: _total(order),
          balanceCentavos: _balance(order),
          actionsEnabled:
              !_denied &&
              !_loading &&
              !_cached &&
              !_savingTargets.contains(order.id),
          cached: _cached,
          onAction: (action) => _orderAction(order, action),
          onResolveReceipt: () async {
            if (!await _dependency('runs')) return;
            final run = _runs
                .where((r) => r.id == order.string('runId'))
                .firstOrNull;
            if (run != null) {
              await _runAction(run, 'resolveReceipt', order: order);
            } else if (mounted) {
              setState(
                () => _error =
                    'Load the delivery run before resolving this receipt.',
              );
            }
          },
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    ),
  );

  String _orderPaymentSummary(CompanyRecord order) {
    final confirmed = order.number('paymentConfirmedCentavos');
    if (order.string('paymentMethod') == 'qr') {
      if (confirmed == 0) return 'QR payment · awaiting supplier confirmation';
      return 'QR payment · ${_peso(confirmed)} confirmed';
    }
    final evidence = order.data['deliveryEvidence'];
    if (evidence is Map && evidence['proof'] is Map) {
      final cash =
          (evidence['proof'] as Map)['cashCollectedCentavos'] as int? ?? 0;
      if (cash > 0) return 'Cash on delivery · ${_peso(cash)} collected';
    }
    return 'Cash on delivery · pay the rider when the order arrives';
  }

  String _orderStatusText(CompanyRecord order) {
    if (order.string('receiptStatus') == 'needsReview') return 'Needs review';
    if (companyOrderQueueTab(order) == CompanyOrderQueueTab.completed) {
      return 'Completed';
    }
    return switch (order.status) {
      'submitted' => 'Awaiting',
      'awaitingConfirmation' => 'Awaiting',
      'accepted' => 'Accepted',
      'picking' => 'Picking',
      'packed' => 'Ready',
      'dispatched' || 'inTransit' => 'Out for delivery',
      'cancelled' => 'Cancelled',
      'rejected' => 'Rejected',
      _ => _label(order.status),
    };
  }

  String _orderAmount(CompanyRecord order) {
    final cents = _total(order);
    final whole = (cents ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '₱$whole.${(cents % 100).toString().padLeft(2, '0')}';
  }

  String _storeOrderStatus(CompanyRecord order) => switch (order.status) {
    'awaitingConfirmation' => 'Review changes',
    'submitted' => 'Awaiting acceptance',
    _ => _orderStatusText(order),
  };

  bool _storeOrderComplete(CompanyRecord order) =>
      companyOrderQueueTab(order) == CompanyOrderQueueTab.completed;

  List<CompanyRecord> get _visibleStoreOrders {
    final query = _orderSearchController.text.trim().toLowerCase();
    return _orders.where((order) {
      if (_storeOrderFilter == 'active' &&
          (_storeOrderComplete(order) ||
              const {'cancelled', 'rejected'}.contains(order.status))) {
        return false;
      }
      if (_storeOrderFilter == 'completed' && !_storeOrderComplete(order)) {
        return false;
      }
      return query.isEmpty ||
          '${order.id} ${order.string('branchName')} ${_storeOrderStatus(order)} ${order.records('lines').map((line) => line['name']).join(' ')}'
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  Widget _storeOrdersHeader() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text('Your orders', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Track purchases and review changes from your supplier.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _denied || _loading || _saving || _warehouses.isEmpty
              ? null
              : () => _newOrder(),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('New order'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _denied || _loading || _warehouses.isEmpty
                ? null
                : _openItemRequests,
            icon: const Icon(Icons.playlist_add, size: 20),
            label: const Text('Request an item / View requests'),
          ),
        ),
        if (_paymentInstructions.isNotEmpty)
          ExpansionTile(
            key: const PageStorageKey('store-company-payment-instructions'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Company payment instructions'),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_paymentInstructions),
              ),
            ],
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _orderSearchController,
          enabled: !_denied,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Search orders or products',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _orderSearchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear order search',
                    onPressed: () => setState(_orderSearchController.clear),
                    icon: const Icon(Icons.close),
                  ),
            helperText: _pages['orders']?.hasMore == true
                ? 'Searches loaded orders. Load more to search further.'
                : null,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in const {
              'all': 'All',
              'active': 'In progress',
              'completed': 'Completed',
            }.entries)
              ChoiceChip(
                showCheckmark: false,
                label: Text(entry.value),
                selected: _storeOrderFilter == entry.key,
                onSelected: (_) =>
                    setState(() => _storeOrderFilter = entry.key),
              ),
          ],
        ),
        if (_orders.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${_visibleStoreOrders.length} of ${_orders.length} loaded orders',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (_products.isEmpty && !_loading) ...[
          const SizedBox(height: 12),
          const Text(
            'No company products are available yet. You can request an item.',
          ),
        ],
      ],
    );
  }

  Widget _storeOrdersSliver() {
    if (_orders.isEmpty && (_loading || _error != null)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final orders = _visibleStoreOrders;
    if (orders.isEmpty) {
      return SliverToBoxAdapter(
        child: SariSupplyStatus(
          icon: _orders.isEmpty
              ? Icons.shopping_bag_outlined
              : Icons.search_off,
          message: _orders.isEmpty
              ? 'No orders loaded. Start with New order to browse company products.'
              : 'No matching orders in the loaded records.',
          actions: [
            if (_orders.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  _orderSearchController.clear();
                  _storeOrderFilter = 'all';
                }),
                child: const Text('Show all loaded orders'),
              ),
          ],
        ),
      );
    }
    return SliverList.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) => _storeOrderCard(orders[index]),
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final index = orders.indexWhere((order) => order.id == key.value);
        return index < 0 ? null : index;
      },
    );
  }

  Widget _storeOrderCard(CompanyRecord order) {
    final theme = Theme.of(context);
    final created = DateTime.tryParse(order.string('createdAt'))?.toLocal();
    final reference = order.id.length > 8
        ? order.id.substring(order.id.length - 8)
        : order.id;
    final products = order.records('lines').length;
    final status =
        order.string('receiptStatus') == 'needsReview' ||
            order.status == 'awaitingConfirmation'
        ? SsStatus.warning
        : _storeOrderComplete(order)
        ? SsStatus.success
        : const {'cancelled', 'rejected'}.contains(order.status)
        ? SsStatus.error
        : const {'dispatched', 'inTransit'}.contains(order.status)
        ? SsStatus.info
        : SsStatus.neutral;
    return AbsorbPointer(
      key: ValueKey(order.id),
      absorbing: _savingTargets.contains(order.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          key: PageStorageKey('store-order:${order.id}'),
          tilePadding: const EdgeInsets.all(16),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Order #$reference', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SsStatusChip(label: _storeOrderStatus(order), status: status),
                  Text(_orderAmount(order), style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (order.string('branchName').isNotEmpty)
                    order.string('branchName'),
                  '$products ${products == 1 ? 'product' : 'products'}',
                  if (created != null)
                    '${MaterialLocalizations.of(context).formatShortDate(created)} · ${TimeOfDay.fromDateTime(created).format(context)}',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          children: [_storeOrderDetails(order)],
        ),
      ),
    );
  }

  Widget _storeOrderItems(List<Map<String, Object?>> lines) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final line in lines) ...[
        Text('${line['name']}', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '${line['quantity']} ${line['unit']} × ${_peso(line['priceCentavos'] as int)}',
        ),
        Text(
          'Line total · ${_peso((line['quantity'] as int) * (line['priceCentavos'] as int))}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const Divider(height: 24),
      ],
    ],
  );

  Widget _storeOrderDetails(CompanyRecord order) {
    final theme = Theme.of(context);
    final canAct = !_denied && !_loading && !_cached;
    final confirmReceipt =
        order.status == 'dispatched' &&
        order.data['deliveryEvidence'] != null &&
        order.string('receiptStatus') == 'awaitingDelivery';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          if (order.status == 'awaitingConfirmation') ...[
            Text('Review proposed changes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(order.string('changeReason')),
            const SizedBox(height: 12),
            _storeOrderItems(order.records('proposedLines')),
            Text(
              'Revised order total · ${_peso(order.records('proposedLines').fold<int>(0, (sum, line) => sum + (line['quantity'] as int) * (line['priceCentavos'] as int)))}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: canAct
                  ? () => _orderAction(order, 'confirmProposal')
                  : null,
              child: const Text('Confirm revised order'),
            ),
            const SizedBox(height: 20),
          ],
          if (confirmReceipt) ...[
            const Text(
              'Delivery recorded. Confirm only the goods your branch actually received.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _denied || _loading
                  ? null
                  : () => _orderAction(order, 'confirmReceipt'),
              child: const Text('Confirm receipt'),
            ),
            const SizedBox(height: 20),
          ],
          Text('Ordered items', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _storeOrderItems(order.records('lines')),
          if (order.data['deliveryEvidence'] != null)
            Text('Store receipt · ${_label(order.string('receiptStatus'))}'),
          ExpansionTile(
            key: PageStorageKey('store-order-delivery:${order.id}'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Delivery & payment'),
            children: [
              for (final value in [
                order.string('address'),
                order.string('contact'),
                order.string('phone'),
                if (order.string('notes').isNotEmpty)
                  'Note: ${order.string('notes')}',
              ].where((value) => value.isNotEmpty))
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(value),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_orderPaymentSummary(order)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _balance(order) < 0
                      ? 'Overpayment needs review: ${_peso(-_balance(order))}'
                      : order.string('paymentMethod') == 'qr'
                      ? 'QR balance: ${_peso(_balance(order))}'
                      : 'Cash due at delivery: ${_peso(_balance(order))}',
                ),
              ),
              if (order.string('paymentInstructions').isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(order.string('paymentInstructions')),
                ),
              ],
              if (order.string('resolutionNote').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(order.string('resolutionNote')),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Order ID · ${order.id}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          if (const {
            'submitted',
            'awaitingConfirmation',
            'accepted',
          }.contains(order.status))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: canAct
                    ? () => _orderAction(order, 'cancelOrder')
                    : null,
                icon: const Icon(Icons.close, size: 20),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                label: const Text('Cancel order'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _orderCard(CompanyRecord order) => AbsorbPointer(
    key: ValueKey(order.id),
    absorbing: _savingTargets.contains(order.id),
    child: Card(
      key: ValueKey(order.id),
      child: ExpansionTile(
        key: PageStorageKey('order:${order.id}'),
        title: Text(
          _store ? order.string('branchName') : order.string('storeName'),
        ),
        subtitle: Text('${_label(order.status)} · ${_peso(_total(order))}'),
        children: [_orderDetails(order)],
      ),
    ),
  );

  Widget _orderDetails(CompanyRecord o) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${o.string('address')}\n${o.string('contact')} · ${o.string('phone')}',
        ),
        if (o.string('notes').isNotEmpty) Text(o.string('notes')),
        const SizedBox(height: 16),
        ...o
            .records('lines')
            .map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${l['name']} · ${l['quantity']} ${l['unit']} × ${_peso(l['priceCentavos'] as int)}',
                ),
              ),
            ),
        if (o.status == 'awaitingConfirmation') ...[
          _status('Store approval needed: ${o.string('changeReason')}'),
          ...o
              .records('proposedLines')
              .map(
                (l) => Text(
                  '${l['name']} · ${l['quantity']} ${l['unit']} × ${_peso(l['priceCentavos'] as int)}',
                ),
              ),
        ],
        if (o.data['deliveryEvidence'] != null)
          _status('Store receipt: ${_label(o.string('receiptStatus'))}'),
        _status(_orderPaymentSummary(o)),
        _status(
          _balance(o) < 0
              ? 'Overpayment needs review: ${_peso(-_balance(o))}'
              : o.string('paymentMethod') == 'qr'
              ? 'QR balance: ${_peso(_balance(o))}'
              : 'Cash due at delivery: ${_peso(_balance(o))}',
        ),
        if (_store && o.string('paymentInstructions').isNotEmpty)
          ExpansionTile(
            title: const Text('Payment instructions'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(o.string('paymentInstructions')),
              ),
            ],
          ),
        if (o.string('resolutionNote').isNotEmpty)
          Text(o.string('resolutionNote')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!_store && o.status == 'submitted') ...[
              _button('Accept order', () => _orderAction(o, 'acceptOrder')),
              _button('Propose changes', () => _orderAction(o, 'proposeOrder')),
              _button('Reject', () => _orderAction(o, 'rejectOrder')),
            ],
            if (_store && o.status == 'awaitingConfirmation')
              _button(
                'Confirm revised order',
                () => _orderAction(o, 'confirmProposal'),
              ),
            if (_store &&
                [
                  'submitted',
                  'awaitingConfirmation',
                  'accepted',
                ].contains(o.status))
              _button('Cancel order', () => _orderAction(o, 'cancelOrder')),
            if (!_store && o.status == 'accepted')
              _button('Start picking', () => _orderAction(o, 'startPicking')),
            if (!_store && o.status == 'picking') ...[
              _button('Confirm packing', () => _orderAction(o, 'packOrder')),
              _button('Report shortage', () => _orderAction(o, 'proposeOrder')),
            ],
            if (_store &&
                o.status == 'dispatched' &&
                o.data['deliveryEvidence'] != null &&
                o.string('receiptStatus') == 'awaitingDelivery')
              _button(
                'Confirm receipt',
                () => _orderAction(o, 'confirmReceipt'),
                allowOffline: true,
              ),
            if (!_store &&
                !['cancelled', 'rejected'].contains(o.status) &&
                _balance(o) > 0 &&
                (o.string('paymentMethod').isEmpty ||
                    o.string('paymentMethod') == 'qr'))
              _button('Confirm QR payment', () => _orderAction(o, 'confirmQr')),
            if (!_store && o.string('receiptStatus') == 'needsReview')
              _button('Resolve receipt difference', () async {
                if (!await _dependency('runs')) return;
                final run = _runs
                    .where((r) => r.id == o.string('runId'))
                    .firstOrNull;
                if (run != null) {
                  await _runAction(run, 'resolveReceipt', order: o);
                } else if (mounted) {
                  setState(
                    () => _error =
                        'Load the delivery run before resolving this receipt.',
                  );
                }
              }),
          ],
        ),
      ],
    ),
  );

  Widget _deliveryRunRow(CompanyRecord run) {
    final stops = run.records('stops');
    final expanded = _expandedRuns.contains(run.id);
    return CompanyDeliveryQueueRow(
      key: ValueKey(run.id),
      run: run,
      destination: _deliveryRoute(stops),
      orderCount: _deliveryOrderCount(stops),
      recordedAt: _deliveryRunTime(run),
      statusLabel: _deliveryStatusLabel(run),
      statusKind: _deliveryStatusKind(run),
      expanded: expanded,
      absorbing: _savingTargets.contains(run.id),
      onToggle: () => setState(() {
        if (expanded) {
          _expandedRuns.remove(run.id);
        } else {
          _expandedRuns.add(run.id);
        }
      }),
      details: _runDetails(
        run,
        padding: const EdgeInsets.only(bottom: SariSupplySpacing.md),
        includeVehicle: true,
      ),
    );
  }

  Widget _runCard(CompanyRecord r) => AbsorbPointer(
    key: ValueKey(r.id),
    absorbing: _savingTargets.contains(r.id),
    child: Card(
      key: ValueKey(r.id),
      child: ExpansionTile(
        key: PageStorageKey('run:${r.id}'),
        title: Text(r.string('driverName')),
        subtitle: Text(
          '${_label(r.status)} · ${r.records('stops').length} stops · ${r.string('vehicleInfo')}',
        ),
        children: [
          _runDetails(r, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16)),
        ],
      ),
    ),
  );

  Widget _runDetails(
    CompanyRecord r, {
    required EdgeInsetsGeometry padding,
    bool includeVehicle = false,
  }) => Padding(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeVehicle) ...[
          SelectableText(
            'Delivery reference: ${r.id}',
            style: SariSupplyTypography.caption.copyWith(
              color: SariSupplyColors.ink600,
            ),
          ),
          if (r.string('vehicleInfo').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Vehicle · ${r.string('vehicleInfo')}',
                style: SariSupplyTypography.body,
              ),
            ),
        ],
        if (!_rider && r.status == 'draft')
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _denied ||
                          _loading ||
                          _cached ||
                          _savingTargets.contains(r.id)
                      ? null
                      : () => _runAction(r, 'dispatchRun'),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Dispatch delivery'),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Delivery actions',
                enabled:
                    !_denied &&
                    !_loading &&
                    !_cached &&
                    !_savingTargets.contains(r.id),
                onSelected: (_) => _runAction(r, 'cancelRun'),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'cancel',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.cancel_outlined,
                        color: SariSupplyColors.error,
                      ),
                      title: Text(
                        'Cancel draft',
                        style: TextStyle(color: SariSupplyColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ...r
            .records('stops')
            .map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${s['sequence']}. ${s['destinationName']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (includeVehicle)
                      ExpansionTile(
                        key: PageStorageKey('run-contact:${r.id}:${s['id']}'),
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Contact and address'),
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              '${s['destinationAddress']}\n${s['contactPerson']} · ${s['contactPhone']}',
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '${s['destinationAddress']}\n${s['contactPerson']} · ${s['contactPhone']}',
                      ),
                    Text(_label(s['status'] as String)),
                    if (s['localPending'] == true)
                      const Text('Saved locally · Sync pending'),
                    const SizedBox(height: 8),
                    ...(s['items'] as List).map((raw) {
                      final item = Map<String, Object?>.from(raw as Map);
                      final quantity = item['quantityOrdered'] as int;
                      final price = item['unitCostCentavos'] as int;
                      final unit = item['unitName'] as String;
                      return Text(
                        _rider
                            ? '${item['productName']} · $quantity $unit × ${_peso(price)} = ${_peso(quantity * price)}'
                            : '${item['productName']} · $quantity $unit',
                      );
                    }),
                    if (_rider)
                      Text(
                        s['paymentMethod'] == 'qr'
                            ? 'QR payment · collect no cash'
                            : 'Cash due at this stop: ${_peso((s['amountDueCentavos'] as int?) ?? _stopOrderValue(s['items'] as List))}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    if (s['proof'] != null)
                      Text(
                        'Collected ${_peso((s['proof'] as Map)['cashCollectedCentavos'] as int)}',
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_rider && s['proof'] == null) ...[
                          _button(
                            'Directions',
                            () => _maps(s),
                            allowOffline: true,
                          ),
                          _button(
                            'Record delivery',
                            () => _proof(r, s),
                            allowOffline: true,
                          ),
                        ],
                        if (!_rider && s['returnsStatus'] == 'awaitingReceipt')
                          _button(
                            'Receive returns',
                            () => _runAction(r, 'receiveReturns', stop: s),
                          ),
                        if (!_rider && s['returnsStatus'] == 'needsReview')
                          _button(
                            'Resolve return difference',
                            () => _runAction(r, 'resolveReturns', stop: s),
                          ),
                      ],
                    ),
                    if (s['returnsStatus'] != null &&
                        s['returnsStatus'] != 'none')
                      Text('Returns: ${_label(s['returnsStatus'] as String)}'),
                  ],
                ),
              ),
            ),
        if (!_rider && r.status == 'completed') ...[
          _status('Remittance: ${_label(r.string('remittanceStatus'))}'),
          if ([
            'awaitingCollection',
            'needsReview',
          ].contains(r.string('remittanceStatus')))
            _button(
              'Receive cash remittance',
              () => _runAction(r, 'confirmRemittance'),
            ),
          if (r.string('remittanceStatus') == 'needsReview')
            Text(
              'Expected ${_peso(r.number('cashExpectedCentavos'))} · Received ${_peso(r.number('cashReceivedCentavos'))}\n${r.string('remittanceReason')}',
            ),
        ],
      ],
    ),
  );

  Future<void> _maps(Values stop) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': stop['destinationAddress'] as String,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => _error = 'Unable to open Maps.');
    }
  }

  Widget _button(
    String label,
    VoidCallback callback, {
    bool allowOffline = false,
  }) => OutlinedButton(
    onPressed: _denied || _loading || (_cached && !allowOffline)
        ? null
        : callback,
    child: Text(label),
  );
  Widget _status(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text),
  );
  int _balance(CompanyRecord order) {
    final evidence = order.data['deliveryEvidence'];
    final total = evidence is Map
        ? (evidence['items'] as List).fold<int>(
            0,
            (s, l) =>
                s +
                (l['quantityDelivered'] as int) *
                    (l['unitCostCentavos'] as int),
          )
        : _total(order);
    final cash = evidence is Map
        ? ((evidence['proof'] as Map)['cashCollectedCentavos'] as int)
        : 0;
    return total - order.number('paymentConfirmedCentavos') - cash;
  }

  int _total(CompanyRecord order) => order
      .records('lines')
      .fold(
        0,
        (s, l) => s + (l['quantity'] as int) * (l['priceCentavos'] as int),
      );
}

String _peso(int cents) => '₱${(cents / 100).toStringAsFixed(2)}';
int _stopOrderValue(List items) => items.fold<int>(0, (sum, raw) {
  final item = raw as Map;
  return sum +
      (item['quantityOrdered'] as int) * (item['unitCostCentavos'] as int);
});
String _label(String status) => switch (status) {
  'submitted' => 'Awaiting acceptance',
  'awaitingConfirmation' => 'Confirm changes',
  'accepted' => 'Ready to pick',
  'picking' => 'Picking',
  'packed' => 'Ready to assign',
  'dispatched' => 'Out for delivery',
  'inTransit' => 'On route',
  'awaitingDelivery' => 'Awaiting store receipt',
  'awaitingCollection' => 'Awaiting remittance',
  'awaitingReceipt' => 'Awaiting return receipt',
  'needsReview' => 'Needs review',
  'partiallyDelivered' => 'Partially delivered',
  'confirmed' => 'Confirmed',
  'quarantined' => 'Quarantined',
  'resolved' => 'Resolved',
  'completed' => 'Delivery completed',
  _ =>
    status.isEmpty
        ? 'Pending'
        : '${status[0].toUpperCase()}${status.substring(1)}',
};
String _actionLabel(String action) => switch (action) {
  'acceptOrder' => 'Accept order',
  'startPicking' => 'Start picking',
  'confirmProposal' => 'Confirm revised order',
  _ => 'Confirm action',
};

class _OrderFilterSelection {
  const _OrderFilterSelection({
    this.unpaidOnly = false,
    this.receiptReviewOnly = false,
    this.includeOtherStatuses = false,
  });

  final bool unpaidOnly;
  final bool receiptReviewOnly;
  final bool includeOtherStatuses;
}

class _Field {
  const _Field(
    this.key,
    this.label, {
    this.initial = '',
    this.kind = 'text',
    this.optional = false,
    this.options,
    this.picker,
    this.requiredQuantityKey,
  });
  final String key, label, initial, kind;
  final bool optional;
  final Map<String, String>? options;
  final Future<CompanyRecord?> Function()? picker;
  final String? requiredQuantityKey;
}

class _WorkForm extends StatefulWidget {
  const _WorkForm({
    required this.title,
    required this.fields,
    required this.onDraft,
    required this.action,
    this.initial,
    this.explanation,
  });
  final String title, action;
  final List<_Field> fields;
  final Values? initial;
  final Future<void> Function(Values) onDraft;
  final String? explanation;
  @override
  State<_WorkForm> createState() => _WorkFormState();
}

class _WorkFormState extends State<_WorkForm> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _selected = {};
  final Map<String, String> _pickedLabels = {};
  late final OrderDraftWriter _draftWriter = OrderDraftWriter(widget.onDraft);
  bool _submitting = false, _routeSaved = false;
  String? _draftError;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final initial = widget.initial?[f.key]?.toString() ?? f.initial;
      if (f.options != null || f.picker != null) {
        _selected[f.key] = f.picker != null
            ? initial
            : f.options!.containsKey(initial)
            ? initial
            : '';
        _pickedLabels[f.key] =
            widget.initial?['label:${f.key}'] as String? ?? 'Choose a product';
      } else {
        _controllers[f.key] = TextEditingController(text: initial);
      }
    }
  }

  Values _raw() => {
    for (final entry in _pickedLabels.entries)
      'label:${entry.key}': entry.value,
    for (final f in widget.fields)
      f.key: f.options != null || f.picker != null
          ? _selected[f.key]
          : _controllers[f.key]!.text,
  };
  void _saveDraft() => _draftWriter.schedule(_raw());
  Future<void> _leave() async {
    if (_submitting) return;
    _submitting = true;
    try {
      _draftWriter.schedule(_raw());
      await _draftWriter.close();
      _routeSaved = true;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _draftError = 'Unable to save this draft. Retry before leaving.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_form.currentState!.validate()) return;
    final result = <String, Object?>{};
    for (final f in widget.fields) {
      final value =
          (f.options != null || f.picker != null
                  ? _selected[f.key]
                  : _controllers[f.key]!.text)!
              .trim();
      result[f.key] = (f.kind == 'integer' || f.kind == 'signed')
          ? int.parse(value)
          : f.kind == 'money'
          ? _cents(value)
          : value;
    }
    setState(() => _submitting = true);
    try {
      _draftWriter.schedule(_raw());
      await _draftWriter.close();
      _routeSaved = true;
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() => _draftError = 'Unable to save this draft. Retry.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    if (!_routeSaved) {
      _draftWriter.schedule(_raw());
      unawaited(_draftWriter.close().catchError((Object _) {}));
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _routeSaved,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_leave());
    },
    child: Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: widget.title),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _form,
              child: ListView(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                ),
                children: [
                  if (_draftError != null)
                    SariSupplyStatus(message: _draftError!, error: true),
                  if (_submitting) const LinearProgressIndicator(),
                  if (widget.explanation != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(widget.explanation!),
                    ),
                  for (final f in widget.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: f.picker != null
                          ? FormField<String>(
                              initialValue: _selected[f.key],
                              validator: (v) {
                                if (f.requiredQuantityKey != null &&
                                    int.tryParse(
                                          _controllers[f.requiredQuantityKey]
                                                  ?.text ??
                                              '0',
                                        ) ==
                                        0) {
                                  return null;
                                }
                                return v == null || v.isEmpty
                                    ? 'Choose a product'
                                    : null;
                              },
                              builder: (state) => InkWell(
                                onTap: () async {
                                  final product = await f.picker!();
                                  if (product != null && mounted) {
                                    setState(() {
                                      _selected[f.key] = product.id;
                                      _pickedLabels[f.key] =
                                          '${product.string("name")} · ${product.string("unit")}';
                                    });
                                    state.didChange(product.id);
                                    _saveDraft();
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: f.label,
                                    errorText: state.errorText,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _pickedLabels[f.key] ??
                                              'Choose a product',
                                        ),
                                      ),
                                      const Icon(Icons.search),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : f.options != null
                          ? DropdownButtonFormField<String>(
                              initialValue: _selected[f.key]!.isEmpty
                                  ? null
                                  : _selected[f.key],
                              isExpanded: true,
                              decoration: InputDecoration(labelText: f.label),
                              items: f.options!.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value, maxLines: 2),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                _selected[f.key] = v ?? '';
                                _saveDraft();
                              },
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Choose an option'
                                  : null,
                            )
                          : TextFormField(
                              controller: _controllers[f.key],
                              decoration: InputDecoration(labelText: f.label),
                              keyboardType: f.kind == 'text'
                                  ? TextInputType.text
                                  : const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              onChanged: (_) => _saveDraft(),
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) {
                                  return f.optional ? null : 'Enter a value';
                                }
                                if (f.kind == 'signed' &&
                                    int.tryParse(value) == null) {
                                  return 'Enter a whole-number change';
                                }
                                if (f.kind == 'integer' &&
                                    (int.tryParse(value) == null ||
                                        int.parse(value) < 0)) {
                                  return 'Enter a non-negative whole number';
                                }
                                if (f.kind == 'money' &&
                                    !RegExp(
                                      r'^\d+(\.\d{1,2})?$',
                                    ).hasMatch(value)) {
                                  return 'Enter pesos with up to two decimal places';
                                }
                                return null;
                              },
                            ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(widget.action),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

int _cents(String value) {
  final parts = value.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({
    required this.load,
    required this.company,
    this.initialRecords = const [],
    this.initialPage,
    this.onError,
  });
  final List<CompanyRecord> initialRecords;
  final CompanyPage? initialPage;
  final Future<void> Function(Object)? onError;
  final Future<CompanyPage> Function(String? cursor, String query) load;
  final bool company;
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  Timer? _debounce;
  List<CompanyRecord> _records = [];
  String _query = '';
  String? _cursor, _error;
  bool _busy = true, _more = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _records = [...widget.initialRecords];
    _cursor = widget.initialPage?.nextCursor;
    _more = widget.initialPage?.hasMore ?? false;
    _busy = _records.isEmpty && widget.initialPage == null;
    if (_busy || widget.company) _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _request++;
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy && !reset) return;
    final request = ++_request;
    setState(() => _busy = true);
    try {
      final page = await widget.load(reset ? null : _cursor, _query);
      if (!mounted || request != _request) return;
      setState(() {
        _records = reset || widget.company
            ? page.records
            : [..._records, ...page.records];
        _cursor = page.nextCursor;
        _more = page.hasMore;
        _error = null;
      });
    } catch (e) {
      await widget.onError?.call(e);
      if (e is FirebaseException &&
          ['permission-denied', 'unauthenticated'].contains(e.code)) {
        _records = [];
        _more = false;
      }
      if (mounted && request == _request) {
        setState(() => _error = operationErrorMessage(e));
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.company
        ? _records
              .where(
                (r) =>
                    r
                        .string('name')
                        .toLowerCase()
                        .contains(_query.toLowerCase()) ||
                    r
                        .string('sku')
                        .toLowerCase()
                        .contains(_query.toLowerCase()),
              )
              .toList()
        : _records;
    return Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: 'Choose product'),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search products',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      setState(() => _query = v);
                      if (!widget.company) {
                        _request++;
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 200),
                          () => _load(reset: true),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    SariSupplyStatus(message: _error!, error: true),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final p = records[index];
                  return ListTile(
                    key: ValueKey(p.id),
                    leading: ProductThumbnail(
                      imageUrl: p.imageUrl.isEmpty ? null : p.imageUrl,
                      productName: p.string('name').isEmpty
                          ? 'Product'
                          : p.string('name'),
                      size: 44,
                    ),
                    title: Text(p.string('name')),
                    subtitle: Text(
                      widget.company
                          ? '${_peso(p.number('priceCentavos'))} / ${p.string('unit')}'
                          : p.string('unit'),
                    ),
                    trailing: const Icon(Icons.add),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  if (records.isEmpty && !_busy)
                    Text(
                      _more
                          ? 'No matching product on loaded pages. Load more to search further.'
                          : 'No matching products. Add retail products in POS if needed.',
                    ),
                  if (_more)
                    TextButton(
                      onPressed: _busy ? null : () => _load(),
                      child: const Text('Load more products'),
                    ),
                  if (_error != null)
                    TextButton(
                      onPressed: () => _load(reset: true),
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
