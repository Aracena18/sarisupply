import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'order_shop_controller.dart';

class OrderShopScreen extends StatefulWidget {
  const OrderShopScreen({
    super.key,
    required this.title,
    required this.warehouses,
    required this.catalog,
    required this.initial,
    required this.saveDraft,
    required this.clearDraft,
    required this.loadPreferences,
    required this.loadMappings,
    required this.validateProducts,
    required this.submit,
    required this.matchProduct,
    this.retailStore,
    this.hasAccess,
    this.pendingSubmission,
    this.paymentInstructions = '',
  });
  final String title;
  final List<CompanyRecord> warehouses;
  final OrderCatalogController catalog;
  final OrderValues? initial, pendingSubmission;
  final InventoryStore? retailStore;
  final bool Function()? hasAccess;
  final String paymentInstructions;
  final Future<void> Function(OrderValues) saveDraft;
  final Future<void> Function() clearDraft;
  final Future<OrderValues> Function() loadPreferences;
  final Future<List<CompanyRecord>> Function() loadMappings;
  final Future<List<CompanyRecord>> Function(String, List<String>)
  validateProducts;
  final Future<void> Function(OrderValues) submit;
  final Future<CompanyRecord?> Function(InventoryRow) matchProduct;
  @override
  State<OrderShopScreen> createState() => _OrderShopScreenState();
}

class _OrderShopScreenState extends State<OrderShopScreen>
    with WidgetsBindingObserver {
  late final OrderCartController _cart = OrderCartController(
    initial: widget.initial,
  );
  late final OrderDraftWriter _writer = OrderDraftWriter(widget.saveDraft);
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _reviewScroll = ScrollController();
  final _paymentAnchor = GlobalKey();
  final _deliveryAnchor = GlobalKey();
  final Map<String, TextEditingController> _details = {};
  final _detailsForm = GlobalKey<FormState>();
  List<InventoryRow> _shortages = [];
  final Map<String, CompanyRecord> _mappings = {};
  final Set<String> _selectedSuggestions = {};
  String? _warehouse, _error;
  String _query = '';
  Timer? _debounce;
  bool _suggestions = false,
      _busy = false,
      _shortageBusy = false,
      _shortageMore = true,
      _saved = false,
      _detailsTouched = false,
      _leaving = false,
      _reviewDeliveryError = false;
  OrderValues? _pendingPayload;
  bool _sending = false;
  String? _paymentMethod;
  bool _paymentMethodError = false;
  final Map<String, CompanyRecord> _suggestionProducts = {};
  bool get _denied => widget.hasAccess?.call() == false;
  bool get _pending => _pendingPayload != null;
  OrderValues _raw() => {
    'warehouseId': _warehouse,
    'paymentMethod': _paymentMethod,
    for (final e in _details.entries) e.key: e.value.text,
    ..._cart.snapshot(),
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pendingPayload = widget.pendingSubmission;
    _paymentMethod =
        widget.pendingSubmission?['paymentMethod'] as String? ??
        (widget.pendingSubmission != null
            ? 'cashOnDelivery'
            : widget.initial?['paymentMethod'] as String?);
    _warehouse =
        widget.initial?['warehouseId'] as String? ??
        (widget.warehouses.length == 1 ? widget.warehouses.single.id : null);
    if (!widget.warehouses.any((w) => w.id == _warehouse)) {
      _warehouse = widget.warehouses.length == 1
          ? widget.warehouses.single.id
          : null;
    }
    for (final key in ['address', 'contact', 'phone', 'notes']) {
      _details[key] = TextEditingController(
        text: widget.initial?[key] as String? ?? '',
      );
    }
    _cart.addListener(_save);
    widget.catalog.addListener(_catalogChanged);
    _scroll.addListener(_onScroll);
    if (_warehouse != null) unawaited(widget.catalog.load(_warehouse!, ''));
    unawaited(_setup());
    unawaited(_moreShortages());
  }

  void _save() {
    if (!_saved) _writer.schedule(_raw());
  }

  void _catalogChanged() {
    if (!mounted) return;
    if (_denied) {
      _shortages = [];
      _mappings.clear();
      _suggestionProducts.clear();
      _error = 'Your access has changed. Your draft is preserved.';
    }
    setState(() {});
    final warehouse = _warehouse;
    if (warehouse == null) return;
    final page = widget.catalog.page(warehouse, _query);
    for (final product in page.records) {
      _suggestionProducts[product.id] = product;
    }
    // Advance empty filtered pages until the first match; changing query stops
    // this chain because only the currently visible query schedules another read.
    if (page.records.isEmpty &&
        page.hasMore &&
        !page.loading &&
        page.error == null) {
      unawaited(widget.catalog.load(warehouse, _query, more: true));
    }
  }

  void _onScroll() {
    if (!_suggestions &&
        _scroll.hasClients &&
        _scroll.position.extentAfter < 300 &&
        _warehouse != null) {
      unawaited(widget.catalog.load(_warehouse!, _query, more: true));
    }
  }

  Future<void> _setup() async {
    try {
      final prefs = await widget.loadPreferences();
      if (!mounted) return;
      if (!_detailsTouched) {
        for (final key in ['address', 'contact', 'phone']) {
          if (_details[key]!.text.isEmpty) {
            _details[key]!.text = prefs[key] as String? ?? '';
          }
        }
        final wh = prefs['warehouseId'] as String?;
        if (widget.initial?['warehouseId'] == null &&
            wh != null &&
            widget.warehouses.any((w) => w.id == wh)) {
          _warehouse = wh;
          unawaited(widget.catalog.load(wh, _query));
        }
        setState(() {});
      }
      final mappings = await widget.loadMappings();
      if (!mounted) return;
      for (final m in mappings) {
        final factor = m.number('retailUnitsPerCompanyUnit');
        if (factor >= 1 &&
            factor <= 10000 &&
            m.string('productId').isNotEmpty) {
          _mappings[m.id] = m;
        }
      }
      setState(() {});
      await _prepareSuggestions();
    } catch (e) {
      if (mounted) setState(() => _error = operationErrorMessage(e));
    }
  }

  Future<void> _moreShortages() async {
    final store = widget.retailStore;
    if (store == null || _shortageBusy || !_shortageMore) return;
    setState(() => _shortageBusy = true);
    try {
      final rows = await store.lowStockPage(offset: _shortages.length);
      if (mounted) {
        setState(() {
          _shortages = [..._shortages, ...rows];
          _shortageMore = rows.length == 50;
        });
        await _prepareSuggestions();
      }
    } catch (e) {
      if (mounted) setState(() => _error = operationErrorMessage(e));
    } finally {
      if (mounted) setState(() => _shortageBusy = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void _add(CompanyRecord p, {int count = 1, bool preserve = false}) {
    if (!_cart.add(p, count: count, preserve: preserve)) {
      _notice('Limit: 20 products and 100000 units per product.');
    }
  }

  Future<void> _addSuggestion(InventoryRow row) async {
    if (_warehouse == null) {
      _notice('Choose a supplying warehouse.');
      return;
    }
    var mapping = _mappings[row.product.id];
    if (mapping == null) {
      try {
        mapping = await widget.matchProduct(row);
      } catch (e) {
        if (mounted) setState(() => _error = operationErrorMessage(e));
        return;
      }
      if (!mounted || mapping == null) return;
      setState(() => _mappings[row.product.id] = mapping!);
    }
    if (_cart.products.containsKey(mapping.string('productId'))) return;
    final embedded = mapping.data['product'];
    final product = embedded is Map
        ? CompanyRecord(Map<String, Object?>.from(embedded))
        : _suggestionProducts[mapping.string('productId')];
    if (product == null || product.data['active'] != true) {
      _notice(
        'Matched product is unavailable. Long press to match another product.',
      );
      return;
    }
    _add(
      product,
      count: suggestedCompanyQuantity(
        row.quantity,
        mapping.number('retailUnitsPerCompanyUnit'),
      ),
      preserve: true,
    );
  }

  Future<void> _prepareSuggestions() async {
    final warehouse = _warehouse;
    if (warehouse == null || !mounted) return;
    final ids = _shortages
        .map((r) => _mappings[r.product.id]?.string('productId'))
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    try {
      for (var i = 0; i < ids.length; i += 20) {
        final fresh = await widget.validateProducts(
          warehouse,
          ids.sublist(i, (i + 20).clamp(0, ids.length)),
        );
        if (!mounted || warehouse != _warehouse) return;
        for (final p in fresh) {
          _suggestionProducts[p.id] = p;
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = operationErrorMessage(e));
    }
  }

  void _addSelectedSuggestions() {
    for (final row in _shortages.where(
      (r) => _selectedSuggestions.contains(r.product.id),
    )) {
      final mapping = _mappings[row.product.id];
      if (mapping == null) continue;
      final embedded = mapping.data['product'];
      final product = embedded is Map
          ? CompanyRecord(Map<String, Object?>.from(embedded))
          : _suggestionProducts[mapping.string('productId')];
      if (product == null || product.data['active'] != true) continue;
      _add(
        product,
        count: suggestedCompanyQuantity(
          row.quantity,
          mapping.number('retailUnitsPerCompanyUnit'),
        ),
        preserve: true,
      );
    }
  }

  Future<void> _review() async {
    if (_busy || _denied) return;
    if (_warehouse == null) {
      _notice('Choose a supplying warehouse.');
      return;
    }
    if (_cart.products.isEmpty && !_pending) {
      _notice('Add products before reviewing your order.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _writer.flush();
      if (!_pending) {
        final fresh = await widget.validateProducts(
          _warehouse!,
          _cart.products.keys.toList(),
        );
        if (!mounted) return;
        if (fresh.length != _cart.products.length ||
            fresh.any((p) => p.data['active'] != true)) {
          throw StateError(
            'A cart product is unavailable. Remove it before ordering.',
          );
        }
        final changed = fresh
            .where((p) => _cart.products[p.id]!.revision != p.revision)
            .toList();
        if (changed.isNotEmpty) {
          final yes = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Review changed prices'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in changed)
                      Text(
                        '${p.string('name')}: ${_peso(_cart.products[p.id]!.number('priceCentavos'))} → ${_peso(p.number('priceCentavos'))} / ${p.string('unit')}',
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Keep cart'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Accept prices'),
                ),
              ],
            ),
          );
          if (yes != true || !mounted) return;
        }
        _cart.replaceQuotes(fresh);
        await _writer.flush();
      }
      if (!mounted) return;
      if (_pending) {
        await _submit(_pendingPayload!);
        return;
      }
      setState(() => _busy = false);
      await _showReview();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : operationErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit(OrderValues values) async {
    if (_sending) return;
    _sending = true;
    if (mounted) setState(() => _busy = true);
    try {
      await _writer.flush();
      _pendingPayload = values;
      await widget.submit(values);
      await _writer.close();
      _saved = true;
      await widget.clearDraft();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!isRetryableOperationError(e) && e is! StateError) {
        _pendingPayload = null;
      }
      rethrow;
    } finally {
      _sending = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  void _revealReviewSection(GlobalKey anchor) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = anchor.currentContext;
      if (target != null && target.mounted) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 200),
            alignment: 0,
          ),
        );
      }
    });
  }

  Future<void> _confirmOrder(BuildContext sheet, StateSetter update) async {
    if (!_detailsForm.currentState!.validate() || _cart.products.isEmpty) {
      update(() => _reviewDeliveryError = true);
      _revealReviewSection(_deliveryAnchor);
      return;
    }
    if (_paymentMethod == null ||
        (_paymentMethod == 'qr' && widget.paymentInstructions.trim().isEmpty)) {
      update(() => _paymentMethodError = true);
      _revealReviewSection(_paymentAnchor);
      return;
    }
    if (_busy || _denied || _sending) return;
    final yes = await showDialog<bool>(
      context: sheet,
      builder: (c) => AlertDialog(
        title: const Text('Submit order?'),
        scrollable: true,
        content: Text(
          '${_cart.products.length} products · ${_peso(_cart.total)}\n'
          'Payment · ${_paymentMethod == 'qr' ? 'QR (awaiting supplier confirmation)' : 'Cash on delivery'}\n'
          '${_details['address']!.text}\n'
          'The warehouse must accept this order before fulfillment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Submit order'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted || !sheet.mounted || _denied || _busy) return;
    Navigator.pop(sheet);
    final values = <String, Object?>{
      'warehouseId': _warehouse,
      'paymentMethod': _paymentMethod,
      for (final e in _details.entries) e.key: e.value.text.trim(),
      'lines': [
        for (final p in _cart.products.values)
          {
            'productId': p.id,
            'productRevision': p.revision,
            'quantity': _cart.quantity(p.id).value,
          },
      ],
    };
    try {
      await _submit(values);
    } catch (e) {
      if (mounted) {
        setState(() => _error = operationErrorMessage(e));
      }
    }
  }

  Future<void> _showReview() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) {
          final theme = Theme.of(sheet);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheet).bottom,
            ),
            child: FractionallySizedBox(
              heightFactor: .92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Review order',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close review',
                          onPressed: () => Navigator.pop(sheet),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Form(
                      key: _detailsForm,
                      child: SingleChildScrollView(
                        controller: _reviewScroll,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Items', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            AnimatedBuilder(
                              animation: _cart,
                              builder: (c, _) => Column(
                                children: [
                                  for (final product in _cart.products.values)
                                    _ShopProductRow(
                                      product: product,
                                      quantity: _cart.quantity(product.id),
                                      enabled: !_busy && !_denied,
                                      onAdd: () => _add(product),
                                      onRemove: () => _cart.setQuantity(
                                        product.id,
                                        _cart.quantity(product.id).value - 1,
                                      ),
                                      onSet: (quantity) => _cart.setQuantity(
                                        product.id,
                                        quantity,
                                      ),
                                      showAvailability: false,
                                      margin: const EdgeInsets.only(bottom: 12),
                                    ),
                                  if (_cart.products.isEmpty)
                                    const Text(
                                      'Your cart is empty. Close review to add products.',
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Delivery details',
                              key: _deliveryAnchor,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check the address and recipient before submitting.',
                              style: theme.textTheme.bodySmall,
                            ),
                            for (final e in _details.entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: TextFormField(
                                  controller: e.value,
                                  maxLength: e.key == 'address'
                                      ? 250
                                      : e.key == 'contact'
                                      ? 120
                                      : e.key == 'phone'
                                      ? 40
                                      : 200,
                                  decoration: InputDecoration(
                                    labelText: switch (e.key) {
                                      'address' => 'Delivery address',
                                      'contact' => 'Recipient name',
                                      'phone' => 'Contact number',
                                      _ => 'Order notes (optional)',
                                    },
                                  ),
                                  keyboardType: e.key == 'phone'
                                      ? TextInputType.phone
                                      : TextInputType.text,
                                  onChanged: (_) {
                                    _detailsTouched = true;
                                    update(() => _reviewDeliveryError = false);
                                    _save();
                                  },
                                  validator: (v) =>
                                      e.key != 'notes' &&
                                          (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'Payment method',
                              style: Theme.of(sheet).textTheme.titleMedium,
                            ),
                            RadioGroup<String>(
                              groupValue: _paymentMethod,
                              onChanged: (value) {
                                if (_pending || value == null) return;
                                update(() {
                                  _paymentMethod = value;
                                  _paymentMethodError = false;
                                });
                                _save();
                              },
                              child: Column(
                                children: [
                                  RadioListTile<String>(
                                    value: 'cashOnDelivery',
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      'Cash on delivery',
                                      key: _paymentAnchor,
                                    ),
                                    subtitle: const Text(
                                      'Pay the rider when the order arrives.',
                                    ),
                                    enabled: !_pending,
                                  ),
                                  RadioListTile<String>(
                                    value: 'qr',
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('QR payment'),
                                    subtitle: Text(
                                      widget.paymentInstructions.trim().isEmpty
                                          ? 'Unavailable · ask the supplier to set up QR payments.'
                                          : 'Pay the supplier using these details.',
                                    ),
                                    enabled:
                                        !_pending &&
                                        widget.paymentInstructions
                                            .trim()
                                            .isNotEmpty,
                                  ),
                                ],
                              ),
                            ),
                            if (_paymentMethod == 'qr' &&
                                widget.paymentInstructions.trim().isNotEmpty)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: SariSupplyColors.ink50,
                                  borderRadius: BorderRadius.circular(
                                    SariSupplyRadii.sm,
                                  ),
                                ),
                                child: Text(widget.paymentInstructions),
                              ),
                            if (_paymentMethod == 'qr')
                              Text(
                                'Payment stays pending until the supplier confirms it.',
                                style: Theme.of(sheet).textTheme.bodySmall,
                              ),
                            if (_paymentMethodError)
                              const Padding(
                                padding: EdgeInsets.only(top: 4, bottom: 8),
                                child: Text(
                                  'Choose an available payment method to continue.',
                                  style: TextStyle(
                                    color: SariSupplyColors.error,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),
                            Text(
                              'The warehouse must accept this order before fulfillment.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: AnimatedBuilder(
                        animation: _cart,
                        builder: (c, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Order total',
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  _peso(_cart.total),
                                  style: theme.textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_reviewDeliveryError || _paymentMethodError)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _reviewDeliveryError
                                      ? 'Check the required delivery details above.'
                                      : 'Choose an available payment method above.',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            FilledButton(
                              onPressed:
                                  _cart.products.isEmpty || _busy || _denied
                                  ? null
                                  : () => _confirmOrder(sheet, update),
                              child: const Text('Submit order'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _leave() async {
    if (_leaving || _busy) return;
    _leaving = true;
    try {
      await _writer.flush();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Unable to save your draft. Retry before leaving.',
        );
      }
    } finally {
      _leaving = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_saved) {
      unawaited(
        _writer.flush().catchError((Object e) {
          if (mounted) {
            setState(
              () => _error = 'Unable to save the draft. Retry before leaving.',
            );
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    widget.catalog.removeListener(_catalogChanged);
    _cart.removeListener(_save);
    _reviewScroll.dispose();
    _scroll.dispose();
    _search.dispose();
    for (final c in _details.values) {
      c.dispose();
    }
    _cart.dispose();
    if (!_saved) unawaited(_writer.close().catchError((Object _) {}));
    super.dispose();
  }

  void _changeSearch(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      value.trim().isEmpty ? Duration.zero : const Duration(milliseconds: 300),
      () {
        if (!mounted) return;
        setState(() => _query = value.trim().toLowerCase());
        if (_warehouse != null) {
          unawaited(widget.catalog.load(_warehouse!, _query));
        }
      },
    );
  }

  Widget _cartFooter() => AnimatedBuilder(
    animation: _cart,
    builder: (c, _) {
      final theme = Theme.of(c);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_pending) ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  _cart.products.isEmpty
                      ? 'Add products to start an order'
                      : '${_cart.products.length} of 20 products',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_cart.products.isNotEmpty)
                  Text(_peso(_cart.total), style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            onPressed: _busy || _denied || (!_pending && _cart.products.isEmpty)
                ? null
                : _review,
            child: Text(
              _busy
                  ? 'Checking order…'
                  : _pending
                  ? 'Retry pending submission'
                  : 'Review order',
            ),
          ),
        ],
      );
    },
  );

  Widget _suggestionCard(InventoryRow row) => AnimatedBuilder(
    animation: _cart,
    builder: (context, _) {
      final theme = Theme.of(context);
      final mapping = _mappings[row.product.id];
      final productId = mapping?.string('productId');
      final inCart = productId != null && _cart.products.containsKey(productId);
      final embedded = mapping?.data['product'];
      final matched = embedded is Map
          ? CompanyRecord(Map<String, Object?>.from(embedded))
          : _suggestionProducts[productId];
      final enabled = !_busy && !_pending && !_denied;
      return Card(
        key: ValueKey('suggestion:${row.product.id}'),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _selectedSuggestions.contains(row.product.id),
                    semanticLabel: 'Select ${row.product.name}',
                    onChanged: !enabled || mapping == null || inCart
                        ? null
                        : (selected) => setState(() {
                            if (selected == true) {
                              _selectedSuggestions.add(row.product.id);
                            } else {
                              _selectedSuggestions.remove(row.product.id);
                            }
                          }),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        row.product.name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SsStatusChip(
                    label: row.quantity <= 0 ? 'Out of stock' : 'Low stock',
                    status: row.quantity <= 0
                        ? SsStatus.error
                        : SsStatus.warning,
                  ),
                  Text(
                    'On this device: ${row.quantity} ${row.product.baseUnit}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (mapping != null) ...[
                Text(
                  'Suggested order: ${suggestedCompanyQuantity(row.quantity, mapping.number('retailUnitsPerCompanyUnit'))} ${matched?.string('unit').isNotEmpty == true ? matched!.string('unit') : 'company units'}',
                  style: theme.textTheme.labelLarge,
                ),
                if (matched != null)
                  Text(
                    matched.string('name'),
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
              ] else ...[
                const Text(
                  'Match this retail product to a company product before adding it.',
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (mapping != null)
                    OutlinedButton.icon(
                      onPressed: !enabled || inCart
                          ? null
                          : () => _addSuggestion(row),
                      icon: Icon(inCart ? Icons.check : Icons.add, size: 20),
                      label: Text(inCart ? 'In your order' : 'Add to order'),
                    ),
                  TextButton(
                    onPressed: !enabled
                        ? null
                        : () async {
                            final result = await widget.matchProduct(row);
                            if (mounted && result != null) {
                              setState(
                                () => _mappings[row.product.id] = result,
                              );
                            }
                          },
                    child: Text(
                      mapping == null ? 'Match product' : 'Change match',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final page = _warehouse == null
        ? null
        : widget.catalog.page(_warehouse!, _query);
    return PopScope(
      canPop: _saved,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: sariSupplyTaskAppBar(
          context,
          title: 'Order from ${widget.title}',
          actions: [
            IconButton(
              tooltip: 'Refresh catalog',
              onPressed:
                  _warehouse == null ||
                      _busy ||
                      _denied ||
                      page?.loading == true
                  ? null
                  : () => widget.catalog.load(_warehouse!, _query, force: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _cartFooter(),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  ),
                  sliver: SliverList.list(
                    children: [
                      if (_busy || page?.loading == true) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        if (page?.records.isEmpty != false)
                          const Text('Loading products…'),
                        const SizedBox(height: 12),
                      ],
                      if (_error != null)
                        SariSupplyStatus(message: _error!, error: true),
                      if (page?.error != null)
                        SariSupplyStatus(
                          message: operationErrorMessage(page!.error!),
                          error: true,
                        ),
                      if (_pending)
                        const SariSupplyStatus(
                          message:
                              'Previous submission pending. Retry confirms that order; cart editing is paused.',
                        ),
                      if (widget.warehouses.length == 1)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supplying warehouse',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.warehouses.single.string('name'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey('order-warehouse:$_warehouse'),
                          initialValue: _warehouse,
                          decoration: const InputDecoration(
                            labelText: 'Supplying warehouse',
                          ),
                          isExpanded: true,
                          items: [
                            for (final w in widget.warehouses)
                              DropdownMenuItem(
                                value: w.id,
                                child: Text(w.string('name')),
                              ),
                          ],
                          onChanged: _busy || _pending || _denied
                              ? null
                              : (id) {
                                  setState(() {
                                    _warehouse = id;
                                    _detailsTouched = true;
                                    _suggestionProducts.clear();
                                  });
                                  _save();
                                  if (id != null) {
                                    unawaited(widget.catalog.load(id, _query));
                                    unawaited(_prepareSuggestions());
                                  }
                                },
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            showCheckmark: false,
                            label: const Text('All products'),
                            selected: !_suggestions,
                            onSelected: (_) =>
                                setState(() => _suggestions = false),
                          ),
                          if (widget.retailStore != null)
                            ChoiceChip(
                              showCheckmark: false,
                              label: const Text('Suggested reorder'),
                              selected: _suggestions,
                              onSelected: (_) =>
                                  setState(() => _suggestions = true),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_suggestions)
                        TextField(
                          controller: _search,
                          enabled: !_busy && !_pending && !_denied,
                          decoration: InputDecoration(
                            labelText: 'Search name or SKU',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _search.clear();
                                      _changeSearch('');
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                          onChanged: _changeSearch,
                        ),
                      if (page?.updatedAt != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${page!.cached ? 'Saved catalog' : 'Catalog refreshed'} · ${TimeOfDay.fromDateTime(page.updatedAt!.toLocal()).format(context)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Availability is confirmed when the warehouse accepts your order.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_suggestions)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _busy || _pending || _denied
                                  ? null
                                  : () => setState(() {
                                      _selectedSuggestions.addAll(
                                        _shortages
                                            .where(
                                              (r) => _mappings.containsKey(
                                                r.product.id,
                                              ),
                                            )
                                            .map((r) => r.product.id),
                                      );
                                    }),
                              child: const Text('Select mapped'),
                            ),
                            FilledButton(
                              onPressed:
                                  _busy ||
                                      _pending ||
                                      _denied ||
                                      _selectedSuggestions.isEmpty
                                  ? null
                                  : _addSelectedSuggestions,
                              child: const Text('Add selected'),
                            ),
                          ],
                        ),
                      if (_suggestions) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Low stock on this device',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text('Check incoming orders before adding more.'),
                        ExpansionTile(
                          key: const PageStorageKey('reorder-quantity-policy'),
                          tilePadding: EdgeInsets.zero,
                          title: const Text('How quantities are suggested'),
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Suggestions use this branch’s device inventory: stock at 10 or fewer retail base units, with a target of 20. Product matches define the conversion to company selling units.',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (_suggestions)
                  SliverList.builder(
                    itemCount: _shortages.length,
                    itemBuilder: (c, i) {
                      final row = _shortages[i];
                      return _suggestionCard(row);
                    },
                  )
                else
                  SliverList.builder(
                    itemCount: page?.records.length ?? 0,
                    itemBuilder: (c, i) {
                      final p = page!.records[i];
                      return _ShopProductRow(
                        key: ValueKey('${_warehouse!}:${p.id}'),
                        product: p,
                        quantity: _cart.quantity(p.id),
                        enabled: !_busy && !_pending && !_denied,
                        onAdd: () => _add(p),
                        onRemove: () => _cart.setQuantity(
                          p.id,
                          _cart.quantity(p.id).value - 1,
                        ),
                        onSet: (n) => _cart.setQuantity(p.id, n),
                      );
                    },
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_warehouse == null)
                          const Text('Choose a warehouse to browse products.'),
                        if (!_suggestions &&
                            page != null &&
                            page.records.isEmpty &&
                            !page.loading)
                          Text(
                            page.hasMore
                                ? 'No matches on this page. Search further in the catalog.'
                                : _query.isEmpty
                                ? 'No catalog products yet. You can request an item from order history.'
                                : 'No matching products.',
                          ),
                        if (_suggestions &&
                            _shortages.isEmpty &&
                            !_shortageBusy)
                          const Text('No low-stock products on this device.'),
                        if (_suggestions &&
                            _shortageMore &&
                            widget.retailStore != null)
                          OutlinedButton(
                            onPressed:
                                _shortageBusy || _busy || _pending || _denied
                                ? null
                                : _moreShortages,
                            child: const Text('Load more suggestions'),
                          ),
                        if (!_suggestions && page?.hasMore == true)
                          OutlinedButton(
                            onPressed:
                                page!.loading || _busy || _pending || _denied
                                ? null
                                : () => widget.catalog.load(
                                    _warehouse!,
                                    _query,
                                    more: true,
                                  ),
                            child: const Text('Load more products'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopProductRow extends StatelessWidget {
  const _ShopProductRow({
    super.key,
    required this.product,
    required this.quantity,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    required this.onSet,
    this.showAvailability = true,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });
  final CompanyRecord product;
  final ValueNotifier<int> quantity;
  final bool enabled, showAvailability;
  final EdgeInsetsGeometry margin;
  final VoidCallback onAdd, onRemove;
  final void Function(int) onSet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductThumbnail(
                  imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl,
                  productName: product.string('name').isEmpty
                      ? 'Product'
                      : product.string('name'),
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.string('name'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_peso(product.number('priceCentavos'))} / ${product.string('unit')}',
                      ),
                      if (product.string('sku').isNotEmpty)
                        Text(
                          'SKU: ${product.string('sku')}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<int>(
              valueListenable: quantity,
              builder: (c, n, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showAvailability)
                        SsStatusChip(
                          label: switch (product.string('availability')) {
                            'outOfStock' => 'Out of stock · Backorder',
                            'inStock' => 'In stock',
                            _ => 'Availability unconfirmed',
                          },
                          status: switch (product.string('availability')) {
                            'outOfStock' => SsStatus.warning,
                            'inStock' => SsStatus.success,
                            _ => SsStatus.neutral,
                          },
                        ),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (n > 0)
                            IconButton.outlined(
                              tooltip: 'Remove one',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: enabled ? onRemove : null,
                              icon: const Icon(Icons.remove),
                            ),
                          if (n > 0)
                            TextButton(
                              onPressed: enabled
                                  ? () async {
                                      final value = await showDialog<int>(
                                        context: c,
                                        builder: (_) =>
                                            _QuantityDialog(initial: n),
                                      );
                                      if (value != null) onSet(value);
                                    }
                                  : null,
                              child: Text('$n × ${product.string('unit')}'),
                            ),
                          if (n > 0)
                            IconButton.outlined(
                              tooltip: 'Add product',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: enabled ? onAdd : null,
                              icon: const Icon(Icons.add),
                            )
                          else
                            Tooltip(
                              message: 'Add product',
                              child: OutlinedButton.icon(
                                onPressed: enabled ? onAdd : null,
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Add to order'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (n > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Line total · ${_peso(n * product.number('priceCentavos'))}',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.initial});
  final int initial;
  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final _value = TextEditingController(text: '${widget.initial}');
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Order quantity'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _value,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Whole company units'),
        validator: (v) {
          final n = int.tryParse(v ?? '');
          return n == null || n < 0 || n > 100000 ? 'Enter 0–100000' : null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, int.parse(_value.text));
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

String _peso(int cents) => '₱${(cents / 100).toStringAsFixed(2)}';
