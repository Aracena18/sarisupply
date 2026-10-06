import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

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
      detectionSpeed: DetectionSpeed.noDuplicates);
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
      {super.key, required this.camera, required this.authorize});
  final PhoneBarcodeCamera camera;
  final Future<void> Function() authorize;
  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final _barcode = TextEditingController();
  bool _finished = false, _active = true;
  String? _error;
  Future<void> _operations = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
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
    _barcode.dispose();
    unawaited(_operations.then((_) => widget.camera.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: 'Scan barcode'),
      body: SafeArea(
          child: Column(children: [
        Flexible(
            flex: 2,
            child: widget.camera.preview((code) => unawaited(_finish(code)))),
        Flexible(
            flex: 3,
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_error != null) Text(_error!),
                          TextField(
                              controller: _barcode,
                              decoration:
                                  const InputDecoration(labelText: 'Barcode'),
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (v) {
                                if (v.trim().isNotEmpty) {
                                  unawaited(_finish(v.trim()));
                                }
                              }),
                          const SizedBox(height: 8),
                          FilledButton(
                              onPressed: _barcode.text.trim().isEmpty
                                  ? null
                                  : () => _finish(_barcode.text.trim()),
                              child: const Text('Use barcode')),
                          if (_error != null)
                            TextButton(
                                onPressed: _start,
                                child: const Text('Retry camera')),
                          if (_error != null)
                            TextButton(
                                onPressed: () async {
                                  try {
                                    await widget.camera.openSettings();
                                  } on Object {
                                    if (mounted) {
                                      setState(() => _error =
                                          'Allow camera access in your phone settings');
                                    }
                                  }
                                },
                                child: const Text('Camera settings')),
                          TextButton(
                              onPressed: () => _finish(null),
                              child: const Text('Search instead')),
                        ])))),
      ])));
}
