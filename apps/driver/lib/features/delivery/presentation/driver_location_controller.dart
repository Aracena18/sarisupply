import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import '../data/driver_gps.dart';

/// Location samples are ephemeral; never put them in the delivery outbox.
class DriverLocationController extends ChangeNotifier {
  DriverLocationController(
      {required this.gateway,
      required this.merchantId,
      required this.capture,
      this.interval = const Duration(seconds: 30)});
  final DriverLocationGateway gateway;
  final String merchantId;
  final Future<DriverLocationFix> Function() capture;
  final Duration interval;
  String? _runId;
  bool enabled = false, busy = false, foreground = true;
  bool _disposed = false;
  int _generation = 0, _lastEvent = 0;
  Timer? _timer;
  DriverLocationSnapshot? lastSuccessful;
  String? error;
  int _event() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastEvent = now > _lastEvent ? now : _lastEvent + 1;
    return _lastEvent;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void selectRun(String? id) {
    if (_runId == id) return;
    stop();
    _runId = id;
    lastSuccessful = null;
    error = null;
    _notify();
  }

  Future<void> start() async {
    if (_disposed || _runId == null || !foreground) return;
    enabled = true;
    error = null;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(updateNow()));
    _notify();
    await updateNow();
  }

  Future<void> updateNow() async {
    if (_disposed || !enabled || !foreground || busy || _runId == null) return;
    final generation = _generation, runId = _runId!;
    busy = true;
    error = null;
    _notify();
    try {
      final fix = await capture();
      if (_disposed || generation != _generation || !enabled || !foreground) {
        return;
      }
      final snapshot =
          await gateway.updateDriverLocation(merchantId, runId, fix, _event());
      if (_disposed || generation != _generation) return;
      lastSuccessful = snapshot;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e is LocationCaptureException
          ? e.message
          : e is TimeoutException
              ? 'Location took too long. Move near a window and try again.'
              : operationErrorMessage(e);
      if (e is LocationCaptureException ||
          (e is FirebaseException &&
              ['permission-denied', 'unauthenticated', 'failed-precondition']
                  .contains(e.code))) {
        stop();
      }
    } finally {
      busy = false;
      _notify();
      if (!_disposed && generation != _generation && enabled && foreground) {
        unawaited(updateNow());
      }
    }
  }

  void setForeground(bool value) {
    if (foreground == value) return;
    foreground = value;
    if (!value) {
      _generation++;
      _timer?.cancel();
      if (enabled) _pause();
    } else if (enabled) {
      unawaited(start());
    }
    _notify();
  }

  void _pause() {
    final id = _runId;
    if (id == null) return;
    // A later event fences an already-uploading fix, even if requests arrive out of order.
    final event = _event();
    unawaited(gateway
        .pauseDriverLocation(merchantId, id, event)
        .catchError((Object e) {
      if (!_disposed && _runId == id && !enabled) {
        error =
            '${operationErrorMessage(e)} Last shared position may remain visible.';
        _notify();
      }
    }));
  }

  void stop() {
    final wasEnabled = enabled;
    enabled = false;
    _generation++;
    _timer?.cancel();
    if (wasEnabled) _pause();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
