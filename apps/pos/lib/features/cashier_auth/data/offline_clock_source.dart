import 'package:flutter/services.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

abstract interface class OfflineClockSource {
  Future<OfflineClockReading?> read();
}

/// The Android implementation reports boot count and elapsed realtime.
/// A missing or malformed sample cannot authorize offline login.
final class AndroidOfflineClockSource implements OfflineClockSource {
  const AndroidOfflineClockSource();

  static const _channel = MethodChannel('sarisupply/offline_clock');

  @override
  Future<OfflineClockReading?> read() async {
    try {
      final sample = await _channel.invokeMapMethod<String, Object?>('read');
      final bootCount = sample?['bootCount'];
      final elapsedMs = sample?['elapsedRealtimeMs'];
      if (bootCount is! int ||
          bootCount < 0 ||
          elapsedMs is! int ||
          elapsedMs < 0) {
        return null;
      }
      return OfflineClockReading(
        bootCount: bootCount,
        elapsedRealtime: Duration(milliseconds: elapsedMs),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
