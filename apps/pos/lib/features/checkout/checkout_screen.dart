import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import '../cashier_auth/domain/cashier_login_service.dart';
import 'barcode_scanner_screen.dart';
import 'checkout_controller.dart';
import 'checkout_quantity_controls.dart';
import 'payment_screen.dart';
import 'receipt_screen.dart';
import 'receipt_history_screen.dart';
import 'shift_screen.dart';
import 'customer_credit_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen(
      {super.key,
      required this.openStore,
      required this.session,
      required this.inventoryGateway,
      required this.checkoutGateway,
      required this.authorize,
      required this.grantResolver,
      required this.onLock,
      this.cameraFactory,
      this.onAccessDenied});
  final Future<InventoryStore> Function() openStore;
  final CashierSession session;
  final InventoryGateway inventoryGateway;
  final CheckoutGateway checkoutGateway;
  final Future<CheckoutAuthorization> Function() authorize;
  final Future<IssuedCashierGrant?> Function(CheckoutScope) grantResolver;
  final VoidCallback onLock;
  final Future<void> Function()? onAccessDenied;
  final PhoneBarcodeCamera Function()? cameraFactory;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with WidgetsBindingObserver {
  CheckoutController? _controller;
  final _search = TextEditingController();
  final _focus = FocusNode();
  String? _loadError;
  bool _routePending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    _controller?.removeListener(_changed);
    _controller?.dispose();
    _controller = null;
    setState(() => _loadError = null);
    try {
      final store = await widget.openStore();
      if (!mounted) {
        await store.close();
        return;
      }
      final c = CheckoutController(
          store: store,
          session: widget.session,
          authorize: widget.authorize,
          inventoryGateway: widget.inventoryGateway,
          checkoutGateway: widget.checkoutGateway,
          grantResolver: widget.grantResolver,
          onAccessDenied: widget.onAccessDenied);
      _controller = c;
      c.addListener(_changed);
      await c.load();
      if (!mounted) return;
      setState(() {});
      if (c.recovery != null) {
        await _route(ReceiptScreen(controller: c, sale: c.recovery!));
      }
    } on Object {
      if (mounted) {
        setState(() => _loadError = 'Checkout could not be opened. Try again.');
      }
    }
  }

  void _changed() {
    if (!mounted) return;
    final message = _controller?.takeNotice();
    final reviewPrices = _controller?.noticeNeedsPriceReview == true;
    setState(() {});
    if (message != null) {
      _showNotice(message, reviewPrices: reviewPrices);
    }
  }

  void _showNotice(String message, {bool reviewPrices = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: reviewPrices && _controller?.draft?.lines.isNotEmpty == true
              ? SnackBarAction(label: 'Review prices', onPressed: _prices)
              : null,
        ));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller?.revalidate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_changed);
    _controller?.dispose();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _route(Widget screen) async {
    if (_routePending || !mounted) return;
    setState(() => _routePending = true);
    try {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
    } finally {
      if (mounted) setState(() => _routePending = false);
    }
  }

  Future<void> _scan() async {
    final c = _controller!;
    if (_routePending || !c.editable) return;
    setState(() => _routePending = true);
    _focus.unfocus();
    try {
      await c.flush();
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => BarcodeScannerScreen(
              checkout: c,
              camera: widget.cameraFactory?.call() ?? MobileBarcodeCamera(),
              authorize: () async {
                if (!await c.revalidate()) throw StateError('Checkout locked');
              })));
    } on Object {
      if (mounted) {
        _showNotice('Scan unavailable. Search or enter a barcode.');
      }
    } finally {
      if (mounted) setState(() => _routePending = false);
    }
  }

  Future<void> _submitSearch(String value) async {
    final c = _controller!;
    final match = await c.barcode(value.trim());
    if (match != null) {
      await c.add(match.product, match.unit);
    } else {
      await c.search(value);
    }
  }

  Future<void> _pick(CatalogProduct product) async {
    final c = _controller!;
    if (!c.editable) return;
    if (product.units.length == 1) {
      await c.add(product, product.units.single);
      return;
    }
    final unit = await showSariSupplyForm<CatalogUnit>(
        context: context,
        builder: (context) => SariSupplyFormSurface(
            title: product.name,
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'))
            ],
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final u in product.units)
                ListTile(
                    title: Text('${u.name} · ${formatPhp(u.priceCentavos)}'),
                    subtitle: Text('${u.factor} ${product.baseUnit}'),
                    onTap: () => Navigator.of(context).pop(u))
            ])));
    if (unit != null && mounted) await c.add(product, unit);
  }

  Future<void> _discard() async {
    final c = _controller!;
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(title: const Text('Discard this cart?'), actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Keep cart')),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Discard'))
            ]));
    if (yes == true) await c.discard();
  }

  Future<void> _prices() async {
    final c = _controller!;
    try {
      final lines = await c.currentPrices();
      if (!mounted) return;
      final approved = await showSariSupplyForm<bool>(
          context: context,
          builder: (context) => SariSupplyFormSurface(
              title: 'Review prices',
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Apply changes'))
              ],
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final old in c.draft!.lines)
                  ListTile(
                      title: Text('${old.name} · ${old.unit}'),
                      subtitle: Text(lines.any((l) =>
                              l.productId == old.productId &&
                              l.unit == old.unit)
                          ? '${formatPhp(old.priceCentavos)} → ${formatPhp(lines.firstWhere((l) => l.productId == old.productId && l.unit == old.unit).priceCentavos)}'
                          : 'Unavailable · Remove from cart'))
              ])));
      if (approved == true) await c.applyPrices(lines);
    } on Object {
      if (mounted) {
        _showNotice('Connect and sync before reviewing prices');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final appbar = sariSupplyTaskAppBar(context, title: 'Checkout', actions: [
      PopupMenuButton<String>(
        tooltip: 'Checkout options',
        enabled: c != null && !_routePending,
        onSelected: (value) {
          if (value == 'receipts') {
            _route(ReceiptHistoryScreen(controller: c!));
          } else if (value == 'credit') {
            _route(CustomerCreditScreen(controller: c!));
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'receipts', child: Text('Receipts')),
          PopupMenuItem(value: 'credit', child: Text('Credit accounts')),
        ],
      ),
      IconButton(
          tooltip: 'Shift',
          onPressed: c == null || _routePending
              ? null
              : () => _route(ShiftScreen(controller: c)),
          icon: const Icon(Icons.point_of_sale_outlined)),
      IconButton(
          tooltip: 'Lock',
          onPressed: c?.busy == true ? null : widget.onLock,
          icon: const Icon(Icons.lock_outline)),
    ]);
    if (_loadError != null) {
      return Scaffold(
          appBar: appbar,
          body: SariSupplyPageContent(
              child: SariSupplyStatus(
                  message: _loadError!,
                  error: true,
                  actions: [
                FilledButton(onPressed: _load, child: const Text('Retry'))
              ])));
    }
    if (c == null || c.authorization == null && c.error == null) {
      return Scaffold(
          appBar: appbar,
          body: const Center(child: CircularProgressIndicator()));
    }
    final cart = c.draft;
    return Scaffold(
        appBar: appbar,
        body: SafeArea(
            child: Column(children: [
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            TextField(
                                key: const Key('product-search'),
                                controller: _search,
                                focusNode: _focus,
                                decoration: const InputDecoration(
                                    labelText: 'Search products',
                                    prefixIcon: Icon(Icons.search)),
                                textInputAction: TextInputAction.search,
                                onChanged: c.search,
                                onSubmitted: _submitSearch),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                                onPressed:
                                    c.editable && !_routePending ? _scan : null,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Scan')),
                          ])))),
          Expanded(
              child: SingleChildScrollView(
                  child: Center(
                      child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (c.authorization != null)
                        Text(c.authorization!.branchName,
                            style: SariSupplyTypography.cardHeading),
                      if (c.error != null)
                        SariSupplyStatus(message: c.error!, error: true),
                      if (c.shift == null)
                        FilledButton(
                            onPressed: c.allowed && !_routePending
                                ? () => _route(ShiftScreen(controller: c))
                                : null,
                            child: const Text('Open shift')),
                      if (c.shift != null && !c.ownsShift)
                        const Text(
                            'The current cashier must sign in to close this shift'),
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(c.syncMessage ?? 'Saved on this phone'),
                            TextButton.icon(
                                onPressed: c.syncing || c.busy ? null : c.sync,
                                icon: const Icon(Icons.sync),
                                label: Text(c.syncing ? 'Syncing…' : 'Sync')),
                          ]),
                      if (c.query.trim().isNotEmpty ||
                          cart == null ||
                          cart.lines.isEmpty) ...[
                        if (c.products.isEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(c.query.trim().isEmpty
                                  ? 'Sync to load products'
                                  : 'No products found')),
                        for (final row in c.products)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ProductThumbnail(
                                imageUrl: row.product.thumbnailUrl,
                                productName: row.product.name,
                                size: 44,
                              ),
                              title: Text(row.product.name),
                              subtitle: Text(
                                  '${row.product.sku} · ${row.quantity} ${row.product.baseUnit}\n${formatPhp(row.product.units.first.priceCentavos)} / ${row.product.baseUnit}'),
                              onTap:
                                  c.editable ? () => _pick(row.product) : null),
                      ],
                      if (cart != null && cart.lines.isNotEmpty) ...[
                        const Divider(),
                        Text(
                            'Cart · ${cart.lines.fold<int>(0, (sum, line) => sum + line.quantity)} items',
                            style: Theme.of(context).textTheme.titleLarge),
                        for (var n = 0; n < cart.lines.length; n++)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _CartProductPhoto(
                                    key: ValueKey(
                                        '${cart.lines[n].productId}:${cart.lines[n].unit}'),
                                    store: c.store,
                                    productId: cart.lines[n].productId,
                                    revision: cart.lines[n].catalogRevision,
                                    productName: cart.lines[n].name,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(cart.lines[n].name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                            '${formatPhp(cart.lines[n].priceCentavos)} / ${cart.lines[n].unit}'),
                                        Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              CheckoutQuantityControls(
                                                  key: ValueKey(
                                                      '${cart.lines[n].productId}:${cart.lines[n].unit}'),
                                                  controller: c,
                                                  line: cart.lines[n]),
                                              IconButton(
                                                  tooltip:
                                                      'Remove ${cart.lines[n].name} ${cart.lines[n].unit}',
                                                  onPressed: c.editable
                                                      ? () => c.quantity(n, 0)
                                                      : null,
                                                  icon: const Icon(
                                                      Icons.delete_outline)),
                                            ]),
                                        Text(
                                            formatPhp(
                                                cart.lines[n].totalCentavos),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ],
                              )),
                        Wrap(spacing: 8, children: [
                          TextButton(
                              onPressed: c.editable ? _prices : null,
                              child: const Text('Review prices')),
                          TextButton(
                              onPressed: c.editable ? _discard : null,
                              child: const Text('Discard cart'))
                        ]),
                      ],
                      if (cart == null || cart.lines.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(c.products.isEmpty && c.query.isEmpty
                                ? 'Cart is empty. Sync to load products, then scan or search.'
                                : 'Cart is empty. Scan a barcode or search to add products.')),
                    ])),
          )))),
          if (cart != null && cart.lines.isNotEmpty)
            Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: c.allowed && !c.busy && !_routePending
                            ? () async {
                                await c.flush();
                                if (mounted) {
                                  await _route(PaymentScreen(controller: c));
                                }
                              }
                            : null,
                        child: Text(cart.frozenSale != null
                            ? 'Finish saved payment'
                            : 'Pay ${formatPhp(c.total)}')))),
        ])));
  }
}

/// Local lookup runs independently of checkout and never changes receipt data.
class _CartProductPhoto extends StatefulWidget {
  const _CartProductPhoto(
      {super.key,
      required this.store,
      required this.productId,
      required this.revision,
      required this.productName});
  final InventoryStore store;
  final String productId, productName;
  final int revision;
  @override
  State<_CartProductPhoto> createState() => _CartProductPhotoState();
}

class _CartProductPhotoState extends State<_CartProductPhoto> {
  late Future<InventoryRow?> _product;
  @override
  void initState() {
    super.initState();
    _product = widget.store.getProduct(widget.productId);
  }

  @override
  void didUpdateWidget(covariant _CartProductPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.productId != widget.productId ||
        oldWidget.revision != widget.revision) {
      _product = widget.store.getProduct(widget.productId);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<InventoryRow?>(
      future: _product,
      builder: (context, snapshot) => ProductThumbnail(
          productName: widget.productName,
          imageUrl: snapshot.data?.product.thumbnailUrl,
          size: 44));
}
