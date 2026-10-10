import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'checkout_controller.dart';
import 'checkout_quantity_controls.dart';

abstract interface class PhoneBarcodeCamera {
  Widget preview(ValueChanged<String> onCode);
  Future<void> openSettings();
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

final class MobileBarcodeCamera implements PhoneBarcodeCamera {
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<void> openSettings() async {
    if (!_supported) throw UnsupportedError('Camera settings unavailable');
    await const MethodChannel('sarisupply/camera')
        .invokeMethod<void>('openSettings');
  }

  final controller = MobileScannerController(
      autoStart: false,
      facing: CameraFacing.back,
      returnImage: false,
      formats: [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.itf14
      ],
      detectionSpeed: DetectionSpeed.normal);
  @override
  Widget preview(ValueChanged<String> onCode) => !_supported
      ? const Center(child: Icon(Icons.no_photography_outlined))
      : MobileScanner(
          controller: controller,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final raw = barcode.rawValue;
              if (raw != null && raw.isNotEmpty) {
                onCode(raw);
                break;
              }
            }
          },
          errorBuilder: (context, error) => const Center(
              child: Icon(Icons.no_photography_outlined, size: 48)));
  @override
  Future<void> start() async {
    if (!_supported) throw UnsupportedError("Camera unavailable");
    await controller.start();
  }

  @override
  Future<void> stop() => controller.stop();
  @override
  Future<void> dispose() => controller.dispose();
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen(
      {super.key,
      required this.camera,
      required this.authorize,
      this.checkout});
  final CheckoutController? checkout;
  final PhoneBarcodeCamera camera;
  final Future<void> Function() authorize;
  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final _barcode = TextEditingController();
  bool _finished = false, _active = true;
  String? _error, _lastCode, _productId, _unit, _confirmation;
  bool _processing = false;
  Future<void> _scanOperation = Future.value();
  Timer? _noticeTimer;
  Future<void> _operations = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.checkout?.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  void _detect(String code, {bool manual = false}) {
    if (_finished ||
        !_active ||
        _processing ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final value = code.trim();
    if (value.isEmpty || (!manual && value == _lastCode)) return;
    if (widget.checkout == null) {
      unawaited(_finish(value));
      return;
    }
    if (manual) FocusScope.of(context).unfocus();
    _noticeTimer?.cancel();
    setState(() {
      _processing = true;
      _lastCode = value;
      _confirmation = null;
    });
    _scanOperation = _add(value).whenComplete(() {
      if (mounted) {
        setState(() => _processing = false);
        _noticeTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _confirmation = null);
          }
        });
      }
    });
  }

  Future<void> _add(String value) async {
    final c = widget.checkout!;
    try {
      await widget.authorize();
      if (!mounted || _finished || !_active) return;
      final match = await c.barcode(value);
      if (!mounted || _finished || !_active) return;
      if (match == null) {
        setState(() => _confirmation = 'Barcode not found: $value');
        return;
      }
      final saved = await c.add(match.product, match.unit);
      if (!mounted) return;
      setState(() {
        if (saved) {
          _productId = match.product.id;
          _unit = match.unit.name;
          _confirmation = 'Added to cart';
          _barcode.clear();
        } else {
          _confirmation = c.error ?? 'Item not added. Review cart.';
        }
      });
      if (saved) unawaited(HapticFeedback.lightImpact());
    } on Object {
      if (mounted) {
        setState(() => _confirmation = 'Unable to add item. Review cart.');
      }
    }
  }

  void _start() {
    _operations = _operations.then((_) async {
      if (!mounted || _finished || !_active) return;
      try {
        await widget.authorize();
      } on Object {
        await _finish(null);
        return;
      }
      if (!mounted || _finished || !_active) return;
      try {
        await widget.camera.start();
        if (mounted) {
          setState(() => _error = null);
        }
      } on Object {
        if (mounted) {
          setState(
              () => _error = 'Camera unavailable. Use a barcode or search.');
        }
      }
      if (!_active || _finished) await widget.camera.stop();
    });
  }

  Future<void> _finish(String? code) async {
    if (_finished) return;
    _finished = true;
    try {
      await widget.camera.stop();
    } on Object {/* Route disposal still releases the camera. */}
    await _scanOperation;
    if (mounted) Navigator.of(context).pop(code);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _start();
    } else {
      _operations = _operations.then((_) async {
        try {
          await widget.camera.stop();
        } on Object {/* Camera may be waiting for permission. */}
      });
    }
  }

  @override
  void dispose() {
    _finished = true;
    WidgetsBinding.instance.removeObserver(this);
    widget.checkout?.removeListener(_changed);
    _noticeTimer?.cancel();
    _barcode.dispose();
    unawaited(_operations.then((_) => widget.camera.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_processing,
      child: Scaffold(
        appBar: sariSupplyTaskAppBar(context, title: 'Scan barcode'),
        bottomNavigationBar: widget.checkout == null
            ? null
            : SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                        onPressed: _processing ? null : () => _finish(null),
                        child: Text(
                            'Done · ${formatPhp(widget.checkout!.total)}')))),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              flex: 4,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(fit: StackFit.expand, children: [
                        widget.camera.preview(_detect),
                        IgnorePointer(
                            child: Center(
                                child: FractionallySizedBox(
                                    widthFactor: .8,
                                    heightFactor: .4,
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                            borderRadius:
                                                BorderRadius.circular(12)))))),
                        Positioned(
                            top: 12,
                            right: 12,
                            child: IgnorePointer(
                                child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: .65),
                                        borderRadius:
                                            BorderRadius.circular(24)),
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                  _processing
                                                      ? Icons.hourglass_top
                                                      : Icons.qr_code_scanner,
                                                  size: 16,
                                                  color: Colors.white),
                                              const SizedBox(width: 8),
                                              Text(
                                                  _processing
                                                      ? 'Updating…'
                                                      : 'Ready',
                                                  style: const TextStyle(
                                                      color: Colors.white)),
                                            ]))))),
                      ])))),
          Flexible(
            flex: 3,
            child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: SariSupplyColors.card,
                    border: Border(
                        top: BorderSide(color: SariSupplyColors.divider))),
                child: Material(
                    color: SariSupplyColors.card,
                    child: SingleChildScrollView(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_confirmation != null)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Semantics(
                                            liveRegion: true,
                                            child: Text(_confirmation!))),
                                  if (widget.checkout?.error != null)
                                    Text(widget.checkout!.error!),
                                  if (widget.checkout != null) ...[
                                    for (final line
                                        in widget.checkout!.draft?.lines ?? [])
                                      if (line.productId == _productId &&
                                          line.unit == _unit)
                                        Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: SariSupplyColors
                                                        .divider),
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(line.name,
                                                      style:
                                                          SariSupplyTypography
                                                              .cardHeading),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      '${formatPhp(line.priceCentavos)} / ${line.unit}'),
                                                  const SizedBox(height: 8),
                                                  CheckoutQuantityControls(
                                                      key: ValueKey(
                                                          '${line.productId}:${line.unit}'),
                                                      controller:
                                                          widget.checkout!,
                                                      line: line,
                                                      enabled: !_processing,
                                                      onBusyChanged: (value) {
                                                        if (mounted) {
                                                          setState(() =>
                                                              _processing =
                                                                  value);
                                                        }
                                                      }),
                                                ])),
                                    if (_lastCode != null)
                                      TextButton.icon(
                                          onPressed: _processing ||
                                                  !widget.checkout!.editable
                                              ? null
                                              : () {
                                                  setState(
                                                      () => _lastCode = null);
                                                },
                                          icon:
                                              const Icon(Icons.qr_code_scanner),
                                          label: const Text('Scan again')),
                                  ],
                                  if (_error != null) Text(_error!),
                                  ExpansionTile(
                                      key: ValueKey(_error != null),
                                      initiallyExpanded: _error != null,
                                      tilePadding: EdgeInsets.zero,
                                      leading:
                                          const Icon(Icons.keyboard_outlined),
                                      title: const Text('Enter barcode'),
                                      children: [
                                        TextField(
                                            enabled: !_processing,
                                            controller: _barcode,
                                            decoration: const InputDecoration(
                                                labelText: 'Barcode'),
                                            onChanged: (_) => setState(() {}),
                                            onSubmitted: (v) {
                                              if (v.trim().isNotEmpty) {
                                                _detect(v, manual: true);
                                              }
                                            }),
                                        const SizedBox(height: 8),
                                        FilledButton(
                                            onPressed: _barcode.text
                                                        .trim()
                                                        .isEmpty ||
                                                    _processing
                                                ? null
                                                : () => _detect(_barcode.text,
                                                    manual: true),
                                            child: const Text('Use barcode')),
                                      ]),
                                  if (_error != null)
                                    Wrap(spacing: 8, children: [
                                      TextButton(
                                          onPressed: _start,
                                          child: const Text('Retry camera')),
                                      TextButton(
                                          onPressed: () async {
                                            try {
                                              await widget.camera
                                                  .openSettings();
                                            } on Object {
                                              if (mounted) {
                                                setState(() => _error =
                                                    'Allow camera access in Settings.');
                                              }
                                            }
                                          },
                                          child: const Text('Camera settings')),
                                    ]),
                                  TextButton.icon(
                                      onPressed: _processing
                                          ? null
                                          : () => _finish(null),
                                      icon: const Icon(Icons.search),
                                      label: const Text('Search instead')),
                                ]))))),
          ),
        ])),
      ));
}
