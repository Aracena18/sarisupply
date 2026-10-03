import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_pos/app/firebase_pos_workflow.dart';
import 'package:sarisupply_pos/app/pos_app_gate.dart';
import 'package:sarisupply_pos/features/cashier_auth/data/offline_clock_source.dart';
import 'package:sarisupply_pos/features/cashier_auth/data/secure_offline_credential_store.dart';

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

class _TestUser extends Fake implements User {
  _TestUser(this.uid);

  @override
  final String uid;
}

class _TestAuth extends Fake implements FirebaseAuth {
  _TestAuth(String? uid) : currentUser = uid == null ? null : _TestUser(uid);

  @override
  final User? currentUser;
}

class _Devices extends Fake implements DeviceRepository {
  Object? error;

  @override
  Future<DeviceBootstrap> getBootstrap() async {
    if (error case final Object failure) throw failure;
    return const DeviceBootstrap(
      deviceId: 'device-1',
      merchantId: 'merchant-1',
      branchId: 'branch-a',
      displayName: 'Counter tablet',
    );
  }
}

class _ClockSource implements OfflineClockSource {
  int bootCount = 19;
  Duration elapsedRealtime = const Duration(hours: 2);
  bool available = true;

  @override
  Future<OfflineClockReading?> read() async => available
      ? OfflineClockReading(
          bootCount: bootCount, elapsedRealtime: elapsedRealtime)
      : null;
}

class _HumanIdentity extends Fake implements AuthRepository {}

class _Applications extends Fake implements MerchantApplicationRepository {}

class _Memberships extends Fake implements MembershipRepository {}

class _Cashiers extends Fake implements CashierRepository {}

void main() {
  late _MemoryKeys keys;
  late SecureOfflineCredentialStore store;
  late _Devices devices;
  late _ClockSource offlineClock;
  late DateTime now;
  late FirebasePosWorkflow workflow;

  setUp(() {
    keys = _MemoryKeys();
    store = SecureOfflineCredentialStore(keys);
    devices = _Devices();
    offlineClock = _ClockSource();
    now = DateTime.utc(2026, 9, 28, 12);
    workflow = FirebasePosWorkflow(
      humanAuth: _TestAuth(null),
      deviceAuth: _TestAuth('device:device-1'),
      humanIdentity: _HumanIdentity(),
      applications: _Applications(),
      memberships: _Memberships(),
      devices: devices,
      cashiers: _Cashiers(),
      store: store,
      offlineClock: offlineClock,
      clock: () => now,
    );
  });

  test('online bootstrap persists trusted merchant and branch context',
      () async {
    final snapshot = await workflow.load();

    expect(snapshot.state, PosGateState.deviceReadyCashierLocked);
    expect(snapshot.deviceId, 'device-1');
    expect(snapshot.merchantId, 'merchant-1');
    expect(snapshot.branchId, 'branch-a');
    final context = await store.readDeviceContext('device-1');
    expect(context?.verifiedAt, now);
    expect(context?.clockAnchor?.bootCount, 19);
    expect(context?.clockAnchor?.elapsedRealtime, const Duration(hours: 2));
  });

  test('offline bootstrap restores context only within the trusted window',
      () async {
    await workflow.load();
    devices.error = FirebaseFunctionsException(
      code: 'unavailable',
      message: 'Network unavailable',
    );
    const elapsed = Duration(days: 6);
    now = now.add(elapsed);
    offlineClock.elapsedRealtime += elapsed;

    final snapshot = await workflow.load();

    expect(snapshot.state, PosGateState.deviceReadyCashierLocked);
    expect(snapshot.merchantId, 'merchant-1');
    expect(snapshot.branchId, 'branch-a');
  });

  test('offline bootstrap fails closed after a reboot', () async {
    await workflow.load();
    devices.error = FirebaseFunctionsException(
      code: 'unavailable',
      message: 'Network unavailable',
    );
    now = now.add(const Duration(hours: 1));
    offlineClock.bootCount++;
    offlineClock.elapsedRealtime = const Duration(minutes: 1);

    expect(
        (await workflow.load()).state, PosGateState.offlineCredentialsExpired);
  });

  test('server revocation takes precedence over a valid cached context',
      () async {
    await workflow.load();
    devices.error = FirebaseFunctionsException(
      code: 'permission-denied',
      message: 'Device revoked',
    );

    expect((await workflow.load()).state, PosGateState.deviceRevoked);
    expect(await store.readDeviceContext('device-1'), isNotNull);
  });

  test('cached context for another device cannot authorize this POS', () async {
    await store.saveDeviceContext(StoredDeviceContext(
      deviceId: 'device-2',
      merchantId: 'merchant-2',
      branchId: 'branch-b',
      verifiedAt: now,
      lastObservedWallClock: now,
      clockAnchor: OfflineClockAnchor(
        wallClock: now,
        bootCount: offlineClock.bootCount,
        elapsedRealtime: offlineClock.elapsedRealtime,
      ),
    ));
    workflow = FirebasePosWorkflow(
      humanAuth: _TestAuth(null),
      deviceAuth: _TestAuth('device:device-1'),
      humanIdentity: _HumanIdentity(),
      applications: _Applications(),
      memberships: _Memberships(),
      devices: devices
        ..error = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Network unavailable',
        ),
      cashiers: _Cashiers(),
      store: store,
      offlineClock: offlineClock,
      clock: () => now,
    );

    expect(
        (await workflow.load()).state, PosGateState.offlineCredentialsExpired);
  });
}
