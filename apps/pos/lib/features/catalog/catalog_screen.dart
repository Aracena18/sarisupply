import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import 'product_dialog.dart';
import '../inventory/presentation/receiving_screen.dart';
import '../inventory/presentation/adjustment_screen.dart';
import '../inventory/presentation/transfer_screen.dart';
import '../inventory/presentation/restock_screen.dart';
import '../inventory/presentation/warehouse_fulfillment_screen.dart';
import '../reports/presentation/reports_screen.dart';
import '../notifications/presentation/notification_bell.dart';
import '../diagnostics/presentation/diagnostic_recovery_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen(
      {super.key,
      required this.branchName,
      required this.openStore,
      required this.gateway,
      required this.canUpload,
      required this.canEdit,
      this.onAccessDenied,
      this.onLock});
  final String branchName;
  final Future<InventoryStore> Function() openStore;
  final InventoryGateway gateway;
  final bool canUpload, canEdit;
  final Future<void> Function()? onAccessDenied;
  final VoidCallback? onLock;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  InventoryStore? _store;
  List<InventoryRow> _rows = [];
  List<StockOperation> _operations = [];
  bool _formVisible = false;
  bool _busy = true, _more = false, _shortages = false, _archived = false;
  String _query = '';
  String? _error, _message;
  Timer? _debounce;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = await widget.openStore();
      if (!mounted) {
        await store.close();
        return;
      }
      _store = store;
      _more = await store.hasPendingSync();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final store = _store;
    if (store == null) return;
    final request = ++_request;
    try {
      final rows = await store.search(_query,
          shortagesOnly: _shortages, includeArchived: _archived);
      final operations = await store.operations(unsettledOnly: true);
      if (!mounted || request != _request) return;
      setState(() {
        _rows = rows;
        _operations = operations;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = operationErrorMessage(error));
      }
    }
  }

  Future<void> _sync() async {
    if (_busy || _store == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final more = await InventorySync(_store!, widget.gateway,
              canUpload: widget.canUpload)
          .run();
      if (mounted) {
        setState(() {
          _more = more;
          _message = more ? 'Sync pending' : 'Up to date';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
      if (mounted &&
          error is FirebaseException &&
          ['permission-denied', 'unauthenticated'].contains(error.code)) {
        await widget.onAccessDenied?.call();
      }
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _product([CatalogProduct? product]) async {
    if (_busy || _store == null) return;
    setState(() {
      _busy = true;
      _formVisible = true;
    });
    try {
      final saved = await showSariSupplyForm<bool>(
          context: context,
          builder: (_) => ProductDialog(
              product: product,
              onSave: (p, id) =>
                  widget.gateway.saveProduct(_store!.merchantId, p, id)));
      if (mounted) setState(() => _formVisible = false);
      if (saved == true && mounted) {
        setState(() => _busy = false);
        await _sync();
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _formVisible = false;
        });
      }
    }
  }

  Future<void> _deleteProduct(CatalogProduct product) async {
    if (_busy || _store == null) return;
    final isDeleting = product.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDeleting ? 'Delete Product?' : 'Restore Product?'),
        content: Text(
          isDeleting
              ? 'Are you sure you want to remove "${product.name}" from active sales? Existing transaction records will be preserved.'
              : 'Restore "${product.name}" back into active catalog?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: isDeleting
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isDeleting ? 'Delete' : 'Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = product.copyWith(active: !isDeleting);
      final opId = const Uuid().v4();
      await widget.gateway.saveProduct(_store!.merchantId, updated, opId);
      await _sync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDeleting
                ? '"${product.name}" deleted from catalog.'
                : '"${product.name}" restored to catalog.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = operationErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _count(InventoryRow row) async {
    if (_busy || row.unsettled > 0) return;
    final quantity = TextEditingController();
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final kind = row.revision == 0 ? 'opening' : 'count';
    final id = const Uuid().v4();
    var submitting = false;
    String? error;
    setState(() {
      _busy = true;
      _formVisible = true;
    });
    try {
      final saved = await showSariSupplyForm<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
              builder: (context, setDialog) => PopScope(
                    canPop: !submitting,
                    child: SariSupplyFormSurface(
                      title: kind == 'opening'
                          ? 'Opening stock'
                          : 'Physical count',
                      actions: [
                        TextButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    if (!form.currentState!.validate()) return;
                                    setDialog(() => submitting = true);
                                    try {
                                      await _store!.recordCount(
                                          id: id,
                                          productId: row.product.id,
                                          quantity: int.parse(quantity.text),
                                          kind: kind,
                                          reason: reason.text);
                                      if (context.mounted) {
                                        Navigator.pop(context, true);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        setDialog(() {
                                          error = operationErrorMessage(e);
                                          submitting = false;
                                        });
                                      }
                                    }
                                  },
                            child: Text(submitting
                                ? 'Saving…'
                                : kind == 'opening'
                                    ? 'Save opening stock'
                                    : 'Save count')),
                      ],
                      child: Form(
                          key: form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(row.product.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                    'Current stock: ${row.quantity} ${row.product.baseUnit}'),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: quantity,
                                    enabled: !submitting,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                        labelText:
                                            'Quantity (${row.product.baseUnit})'),
                                    validator: (v) {
                                      final n = int.tryParse(v ?? '');
                                      return n == null ||
                                              n < 0 ||
                                              n > 1000000000
                                          ? 'Enter a whole quantity'
                                          : null;
                                    }),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: reason,
                                    enabled: !submitting,
                                    maxLength: 160,
                                    decoration: const InputDecoration(
                                        labelText: 'Reason'),
                                    validator: (v) => (v ?? '').trim().isEmpty
                                        ? 'Enter a reason'
                                        : null),
                                if (error != null)
                                  SariSupplyStatus(
                                      message: error!, error: true),
                              ])),
                    ),
                  )));
      if (saved == true && mounted) {
        setState(() {
          _message = 'Saved locally · Sync pending';
          _more = true;
        });
      }
      await _load();
    } finally {
      quantity.dispose();
      reason.dispose();
      if (mounted) {
        setState(() {
          _busy = false;
          _formVisible = false;
        });
      }
    }
  }

  Future<void> _withdraw(StockOperation op) async {
    final row = _rows.where((r) => r.product.id == op.productId).firstOrNull;
    final unit = row?.product.baseUnit ?? 'base units';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Withdraw rejected count?'),
                scrollable: true,
                content: Text('${op.productName} · ${op.quantity} $unit\n'
                    'Reason: ${op.reason}\n\n'
                    'This reverses the rejected local count and retains its history. '
                    'Sync stock, then record a new physical count with a reason.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Withdraw'))
                ]));
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await _store!.withdraw(op.id, const Uuid().v4());
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final store = _store;
    if (store != null) unawaited(store.close());
    super.dispose();
  }

  String _price(int cents) =>
      '₱${(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';
  Widget _pendingCounts() => Card(
          child: ExpansionTile(
        title: Text(
            '${_operations.length} stock ${_operations.length == 1 ? 'count' : 'counts'} · ${_operations.any((o) => o.status != 'pending') ? 'Needs review' : 'Sync pending'}'),
        leading: const Icon(Icons.pending_actions),
        children: [
          for (final op in _operations)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          '${op.productName.isEmpty ? 'Stock count' : op.productName} · ${op.quantity}'),
                      Text(op.status == 'pending'
                          ? 'Sync pending'
                          : op.message ?? 'Needs review'),
                      Text('Reason: ${op.reason}'),
                      if (widget.canUpload &&
                          ['conflict', 'blocked'].contains(op.status))
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                                onPressed: _busy ? null : () => _withdraw(op),
                                child: const Text('Withdraw'))),
                    ]))
        ],
      ));

  Widget _row(InventoryRow row) {
    final product = row.product;
    final base = product.units.first;
    final match = product.units
        .where((u) => u.barcode.isNotEmpty && u.barcode == _query.trim())
        .firstOrNull;
    return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionTile(
          key: ValueKey(product.id),
          leading: ProductThumbnail(
            imageUrl: product.imageUrl,
            productName: product.name,
            size: 48,
          ),
          title: Text(product.name,
              style: Theme.of(context).textTheme.titleMedium),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(
                '${row.quantity < 0 ? 'Short ${-row.quantity}' : '${row.quantity} in stock'} ${product.baseUnit}${row.unsettled > 0 ? ' · Sync pending' : ''}'),
            Text('${_price(base.priceCentavos)} / ${base.name}'),
            if (match != null)
              Text(
                  'Barcode match: ${match.name} · ${_price(match.priceCentavos)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          '${product.sku}${product.active ? '' : ' · Archived'}'),
                      for (final unit in product.units.skip(1))
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                                '${unit.name} (${unit.factor} ${product.baseUnit}) · ${_price(unit.priceCentavos)}')),
                      if (widget.canUpload || widget.canEdit)
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (widget.canEdit) ...[
                            TextButton(
                                onPressed:
                                    _busy ? null : () => _product(product),
                                child: const Text('Edit product')),
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _deleteProduct(product),
                                child: Text(
                                  product.active ? 'Delete' : 'Restore',
                                  style: TextStyle(
                                    color: product.active
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                )),
                          ],
                          if (widget.canUpload && product.active) ...[
                            TextButton(
                                onPressed: _busy || row.unsettled > 0
                                    ? null
                                    : () => _count(row),
                                child: Text(row.revision == 0
                                    ? 'Opening stock'
                                    : 'Record count')),
                            TextButton(
                                onPressed: _busy || _store == null
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) => ReceivingScreen(
                                                store: _store!,
                                                product: product,
                                                onReceived: _load))),
                                child: const Text('Receive stock')),
                            TextButton(
                                onPressed: _busy || _store == null
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) => AdjustmentScreen(
                                                store: _store!,
                                                row: row,
                                                onAdjusted: _load))),
                                child: const Text('Adjust stock')),
                            TextButton(
                                onPressed: _busy || _store == null
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) => TransferScreen(
                                                store: _store!,
                                                initialProduct: product,
                                                onCompleted: _load))),
                                child: const Text('Transfer stock')),
                          ],
                        ]),
                    ]))
          ],
        ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: 'Inventory', actions: [
        if (widget.canUpload)
          IconButton(
              onPressed: _busy || _store == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) =>
                          TransferScreen(store: _store!, onCompleted: _load))),
              tooltip: 'Transfers',
              icon: const Icon(Icons.swap_horiz)),
        if (widget.canEdit)
          IconButton(
              onPressed: _busy || _store == null ? null : () => _product(),
              tooltip: 'Add product',
              icon: const Icon(Icons.add)),
        if (_store != null) ...[
          NotificationBell(store: _store!),
          PopupMenuButton<String>(
            tooltip: 'Operations',
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'restock') {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => RestockScreen(
                    store: _store!,
                    isOwner: widget.canEdit,
                    onProposalSubmitted: _load,
                  ),
                ));
              } else if (val == 'warehouse') {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => WarehouseFulfillmentScreen(
                    store: _store!,
                    onFulfillmentUpdated: _load,
                  ),
                ));
              } else if (val == 'reports') {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ReportsScreen(
                    store: _store!,
                    branchName: widget.branchName,
                    isOwner: widget.canEdit,
                    initialTabIndex: 0,
                  ),
                ));
              } else if (val == 'backup') {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ReportsScreen(
                    store: _store!,
                    branchName: widget.branchName,
                    isOwner: widget.canEdit,
                    initialTabIndex: 2,
                  ),
                ));
              } else if (val == 'diagnostics') {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => DiagnosticRecoveryScreen(
                    store: _store!,
                  ),
                ));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'reports',
                child: ListTile(
                  leading: Icon(Icons.analytics_outlined),
                  title: Text('Reports & Z-Reading'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  leading: Icon(Icons.security),
                  title: Text('Data Backup & Archival'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'diagnostics',
                child: ListTile(
                  leading: Icon(Icons.health_and_safety_outlined),
                  title: Text('Diagnostics & Recovery'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'restock',
                child: ListTile(
                  leading: Icon(Icons.autorenew),
                  title: Text('Restock Orders'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'warehouse',
                child: ListTile(
                  leading: Icon(Icons.warehouse),
                  title: Text('Warehouse Ops'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        if (widget.onLock != null)
          IconButton(
              onPressed: widget.onLock,
              tooltip: 'Lock',
              icon: const Icon(Icons.lock_outline)),
      ]),
      body: SariSupplyPageContent(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.branchName, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
            decoration: const InputDecoration(
                labelText: 'Search name, SKU or barcode',
                prefixIcon: Icon(Icons.search)),
            onChanged: (value) {
              _query = value;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 150), _load);
            }),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                  label: const Text('Shortages'),
                  selected: _shortages,
                  onSelected: _busy
                      ? null
                      : (v) {
                          setState(() => _shortages = v);
                          _load();
                        }),
              if (widget.canEdit)
                FilterChip(
                    label: const Text('Archived'),
                    selected: _archived,
                    onSelected: _busy
                        ? null
                        : (v) {
                            setState(() => _archived = v);
                            _load();
                          }),
              TextButton.icon(
                  onPressed: _busy ? null : (_store == null ? _open : _sync),
                  icon: const Icon(Icons.sync),
                  label: Text(_store == null ? 'Retry' : 'Sync')),
            ]),
        if (_busy && !_formVisible) const LinearProgressIndicator(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          SariSupplyStatus(message: _error!, error: true),
        ],
        if (_message != null || _more)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SariSupplyStatus(
                  message: _message ?? 'Sync pending', icon: Icons.sync)),
        if (_operations.isNotEmpty) _pendingCounts(),
        if (!_busy && _rows.isEmpty && _error == null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SariSupplyStatus(
                  message: _query.isNotEmpty || _shortages
                      ? 'No matching products. Change your search or filters.'
                      : 'No products saved. Sync to load your catalog.',
                  icon: Icons.inventory_2_outlined)),
        for (final row in _rows) _row(row),
        if (_rows.length == 50)
          const Text('Showing 50 matches. Refine your search.'),
      ])));
}
