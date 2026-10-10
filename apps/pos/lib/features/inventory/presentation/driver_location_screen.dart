import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverLocationScreen extends StatefulWidget {
  const DriverLocationScreen(
      {super.key,
      required this.merchantId,
      required this.run,
      required this.gateway});
  final String merchantId;
  final Map<String, dynamic> run;
  final DriverLocationGateway gateway;
  @override
  State<DriverLocationScreen> createState() => _DriverLocationScreenState();
}

class _DriverLocationScreenState extends State<DriverLocationScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  DriverLocationSnapshot? _location;
  String? _error;
  bool _busy = false, _foreground = true, _denied = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (_denied) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _start();
    } else {
      _generation++;
      _timer?.cancel();
    }
  }

  Future<void> _refresh() async {
    if (_busy || !_foreground || !mounted || _denied) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final location = await widget.gateway
          .readDriverLocation(widget.merchantId, widget.run['id'] as String);
      if (mounted && generation == _generation) {
        setState(() => _location = location);
      }
    } catch (e) {
      if (!mounted || generation != _generation) return;
      final denied = e is FirebaseException &&
          ['permission-denied', 'unauthenticated', 'not-found']
              .contains(e.code);
      setState(() {
        _error = operationErrorMessage(e);
        if (denied) {
          _denied = true;
          _location = null;
          _timer?.cancel();
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMaps() async {
    final fix = _location?.fix;
    if (fix == null) return;
    try {
      final query = '${fix.latitude},${fix.longitude}';
      final launched = await launchUrl(Uri.parse('geo:$query?q=$query'),
          mode: LaunchMode.externalApplication);
      if (!launched) {
        final fallback = await launchUrl(
            Uri.https('www.google.com', '/maps/search/',
                {'api': '1', 'query': query}),
            mode: LaunchMode.externalApplication);
        if (!fallback) throw StateError('Maps unavailable');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to open Maps. Try again.');
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final age = location == null
        ? null
        : DateTime.now()
            .difference(location.receivedAt)
            .inSeconds
            .clamp(0, 2147483647);
    final fresh =
        location != null && location.isFresh(DateTime.now()) && _error == null;
    return Scaffold(
        appBar: sariSupplyTaskAppBar(context, title: 'Driver location'),
        body: SariSupplyPageContent(
            maxWidth: 700,
            child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  Text(widget.run['driverName'] as String,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(widget.run['vehicleInfo'] as String),
                  const SizedBox(height: 16),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    SariSupplyStatus(message: _error!, error: true),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                    location == null
                                        ? 'No shared location yet'
                                        : fresh
                                            ? 'Recent shared location'
                                            : 'Last known location',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                if (location == null)
                                  const Text(
                                      'The driver must start sharing while the Driver app is open.'),
                                if (location != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                      '${location.fix.latitude.toStringAsFixed(6)}, ${location.fix.longitude.toStringAsFixed(6)}'),
                                  Text(
                                      'Accuracy: ±${location.fix.accuracyMeters.round()} m'),
                                  Text(
                                      'Received ${age! < 60 ? '$age seconds' : '${age ~/ 60} minutes'} ago'),
                                  Text(
                                      'Captured: ${location.fix.capturedAt.toLocal()}'),
                                  Text(location.sharing
                                      ? 'Sharing was active at the last update'
                                      : 'Sharing paused or stopped'),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                      onPressed: _openMaps,
                                      icon: const Icon(Icons.map_outlined),
                                      label: const Text('Open in Maps')),
                                ],
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                    onPressed:
                                        _busy || _denied ? null : _refresh,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Refresh location')),
                                const Text(
                                    'Refreshes every 30 seconds. Foreground sharing pauses when Driver closes or Maps opens.'),
                              ]))),
                  const SizedBox(height: 16),
                  Text('Assigned stops',
                      style: Theme.of(context).textTheme.titleMedium),
                  for (final raw in widget.run['stops'] as List)
                    ListTile(
                        leading: Text('${(raw as Map)['sequence']}'),
                        title: Text(raw['destinationName'] as String),
                        subtitle: Text(raw['destinationAddress'] as String)),
                ])));
  }
}
