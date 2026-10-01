import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/features/cashier_auth/data/offline_clock_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sarisupply/offline_clock');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('decodes the Android boot and elapsed realtime sample', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'read');
      return {'bootCount': 12, 'elapsedRealtimeMs': 7001};
    });
    final sample = await const AndroidOfflineClockSource().read();
    expect(sample?.bootCount, 12);
    expect(sample?.elapsedRealtime, const Duration(milliseconds: 7001));
  });

  test('malformed and unavailable Android samples fail closed', () async {
    messenger.setMockMethodCallHandler(
        channel, (_) async => {'bootCount': -1, 'elapsedRealtimeMs': 7001});
    expect(await const AndroidOfflineClockSource().read(), isNull);
    messenger.setMockMethodCallHandler(
        channel, (_) async => {'bootCount': 12, 'elapsedRealtimeMs': 'bad'});
    expect(await const AndroidOfflineClockSource().read(), isNull);
    messenger.setMockMethodCallHandler(
        channel, (_) async => throw PlatformException(code: 'unavailable'));
    expect(await const AndroidOfflineClockSource().read(), isNull);
  });
}
