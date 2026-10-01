import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

import 'package:sarisupply_pos/features/cashier_auth/data/secure_offline_credential_store.dart';
import 'package:sarisupply_pos/features/cashier_auth/data/offline_clock_source.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';

class _MemoryKeys implements SecureKeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
}

class _Cashiers extends Fake implements CashierRepository {
  bool mustChangePin = false;
  int version = 1;
  DateTime now = DateTime.utc(2026, 9, 27);

  @override
  Future<CashierPinVerification> verifyPin(String cashierId, String pin) async {
    if (pin != '123456') throw StateError('Server rejected PIN');
    return CashierPinVerification(
      cashierId: cashierId,
      credentialVersion: version,
      mustChangePin: mustChangePin,
    );
  }

  @override
  Future<CashierCredentialBundle> refreshCredentialBundle() async =>
      CashierCredentialBundle(
        merchantId: 'merchant-1',
        branchId: 'branch-a',
        issuedAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        cashiers: [
          CashierCredentialProjection(
            cashierId: 'cashier-1',
            displayName: 'Ana',
            employeeCode: 'EMP-1',
            status: 'active',
            assignedBranchIds: ['branch-a'],
            mustChangePin: mustChangePin,
            credentialVersion: version,
          )
        ],
      );
}

class _ClockSource implements OfflineClockSource {
  int bootCount = 7;
  Duration uptime = const Duration(hours: 2);
  bool available = true;

  @override
  Future<OfflineClockReading?> read() async => available
      ? OfflineClockReading(bootCount: bootCount, elapsedRealtime: uptime)
      : null;
}

void main() {
  late _MemoryKeys keys;
  late SecureOfflineCredentialStore store;
  late _Cashiers server;
  late DateTime now;
  late CashierLoginService service;
  late _ClockSource clockSource;

  setUp(() {
    keys = _MemoryKeys();
    store = SecureOfflineCredentialStore(keys);
    server = _Cashiers();
    now = DateTime.utc(2026, 9, 27, 12);
    clockSource = _ClockSource();
    service = CashierLoginService(
      cashiers: server,
      store: store,
      deviceId: 'device-1',
      clock: () => now,
      offlineClock: clockSource,
    );
  });

  test('online permanent PIN enrolls only a derived verifier', () async {
    final login = await service.loginOnline('cashier-1', '123456');
    expect(login.status, CashierLoginStatus.signedIn);
    expect(login.session?.cashierId, 'cashier-1');
    expect(keys.values.values.join(), isNot(contains('123456')));
    expect((await store.read('device-1', 'cashier-1'))?.credentialVersion, 1);
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.signedIn);
  });

  test('temporary PIN requires online change and is never enrolled', () async {
    server.mustChangePin = true;
    expect((await service.loginOnline('cashier-1', '123456')).status,
        CashierLoginStatus.requiresPinChange);
    expect(await store.read('device-1', 'cashier-1'), isNull);
  });

  test('offline failures cool down locally and queue a security event',
      () async {
    await service.loginOnline('cashier-1', '123456');
    for (var attempt = 0; attempt < 5; attempt++) {
      expect((await service.loginOffline('cashier-1', '000000')).status,
          CashierLoginStatus.invalidPin);
    }
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.cooldown);
    expect((await store.queuedSecurityEvents('device-1')).length, 1);
    now = now.add(const Duration(seconds: 31));
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.signedIn);
  });

  test('expiry and newer server version stop offline login', () async {
    await service.loginOnline('cashier-1', '123456');
    now = now.add(const Duration(days: 7));
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.requiresOnlineRefresh);
    now = DateTime.utc(2026, 9, 27, 12);
    server.version = 2;
    await service.refreshEnrollment();
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.requiresOnlineReenrollment);
  });

  test('offline login denies seven elapsed days even when wall time is frozen',
      () async {
    await service.loginOnline('cashier-1', '123456');
    clockSource.uptime += const Duration(days: 7);
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.requiresOnlineRefresh);
  });

  test('offline login denies reboot until an online bundle reanchors it',
      () async {
    await service.loginOnline('cashier-1', '123456');
    clockSource.bootCount++;
    clockSource.uptime = const Duration(minutes: 1);
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.requiresOnlineRefresh);
    await service.refreshEnrollment();
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.signedIn);
  });

  test('missing platform clock fails closed for offline login', () async {
    await service.loginOnline('cashier-1', '123456');
    clockSource.available = false;
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.requiresOnlineRefresh);
  });

  test('pre-anchor stored credential requires an online refresh', () async {
    await service.loginOnline('cashier-1', '123456');
    final key = 'offline-credential:device-1:cashier-1';
    final legacy = jsonDecode(keys.values[key]!) as Map<String, dynamic>;
    legacy.remove('clockAnchor');
    keys.values[key] = jsonEncode(legacy);
    expect((await service.loginOffline('cashier-1', '123456')).status,
        CashierLoginStatus.requiresOnlineRefresh);
  });

  test('clearing a device removes its local verifier and queued events',
      () async {
    await service.loginOnline('cashier-1', '123456');
    await store.queueFailedAttempt(
        deviceId: 'device-1',
        cashierId: 'cashier-1',
        failedAttempts: 5,
        occurredAt: now);
    await store.deleteForDevice('device-1');
    expect(await store.read('device-1', 'cashier-1'), isNull);
    expect(await store.queuedSecurityEvents('device-1'), isEmpty);
  });
}
