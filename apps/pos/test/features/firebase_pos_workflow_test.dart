import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_pos/app/firebase_pos_workflow.dart';
import 'package:sarisupply_pos/app/pos_app_gate.dart';
import 'package:sarisupply_pos/features/cashier_auth/data/offline_clock_source.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';
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
  User? currentUser;
  bool signOutFails = false;

  @override
  Future<void> signOut() async {
    if (signOutFails) {
      throw FirebaseAuthException(code: 'network-request-failed');
    }
    currentUser = null;
  }
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

class _DeviceSession extends Fake implements DeviceTokenSession {}

class _Applications extends Fake implements MerchantApplicationRepository {}

class _Memberships extends Fake implements MembershipRepository {}

class _Cashiers extends Fake implements CashierRepository {
  bool rosterOffline = false;
  bool partialAcknowledgement = false;

  @override
  Future<List<String>> reportOfflinePinFailures(
          List<OfflinePinFailureEvent> events) async =>
      partialAcknowledgement
          ? []
          : events.map((event) => event.eventId).toList();

  @override
  Future<CashierPinVerification> verifyPin(
          String cashierId, String pin) async =>
      CashierPinVerification(
          cashierId: cashierId,
          credentialVersion: 1,
          mustChangePin: false,
          grant: IssuedCashierGrant(
              scope: CheckoutScope(
                  merchantId: 'merchant-1',
                  branchId: 'branch-a',
                  deviceId: 'device-1',
                  cashierId: cashierId,
                  grantId: 'grant-1',
                  credentialVersion: 1),
              secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
              issuedAt: DateTime.utc(2026, 9, 28),
              expiresAt: DateTime.utc(2026, 10, 5)));

  @override
  Future<CashierCredentialBundle> refreshCredentialBundle() async {
    if (rosterOffline) {
      throw FirebaseFunctionsException(code: 'unavailable', message: 'Offline');
    }
    return CashierCredentialBundle(
        merchantId: 'merchant-1',
        branchId: 'branch-a',
        issuedAt: DateTime.utc(2026, 9, 28),
        expiresAt: DateTime.utc(2026, 10, 5),
        cashiers: [
          CashierCredentialProjection(
              cashierId: 'cashier-1',
              displayName: 'Ana',
              employeeCode: 'EMP-1',
              status: 'active',
              assignedBranchIds: ['branch-a'],
              mustChangePin: false,
              credentialVersion: 1)
        ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MemoryKeys keys;
  late SecureOfflineCredentialStore store;
  late _Devices devices;
  late _ClockSource offlineClock;
  late DateTime now;
  late FirebasePosWorkflow workflow;
  late _TestAuth deviceAuth;
  late _Cashiers cashiers;

  setUp(() {
    keys = _MemoryKeys();
    store = SecureOfflineCredentialStore(keys);
    devices = _Devices();
    offlineClock = _ClockSource();
    now = DateTime.utc(2026, 9, 28, 12);
    deviceAuth = _TestAuth('device:device-1');
    cashiers = _Cashiers();
    workflow = FirebasePosWorkflow(
      humanAuth: _TestAuth(null),
      deviceAuth: deviceAuth,
      humanIdentity: _HumanIdentity(),
      applications: _Applications(),
      memberships: _Memberships(),
      devices: devices,
      cashiers: cashiers,
      store: store,
      offlineClock: offlineClock,
      clock: () => now,
    );
  });

  test(
      'blocked bootstrap retains verification recovery instead of blaming internet',
      () async {
    devices.error = FirebaseFunctionsException(
        code: 'unavailable', message: 'App verification unavailable');
    final snapshot = await workflow.load();
    expect(snapshot.state, PosGateState.offlineCredentialsExpired);
    expect(snapshot.recoveryMessage,
        'App verification failed. Retry or contact your administrator.');
    expect(deviceAuth.currentUser, isNotNull);
  });

  test('financial authorization rechecks current session, clock and version',
      () async {
    await workflow.load();
    final session =
        (await workflow.loginCashier('cashier-1', '123456')).session!;
    expect(
        (await workflow.authorizeCheckout(session)).scope.grantId, 'grant-1');
    offlineClock.available = false;
    await expectLater(workflow.authorizeCheckout(session), throwsStateError);
    offlineClock.available = true;
    offlineClock.bootCount++;
    await expectLater(workflow.authorizeCheckout(session), throwsStateError);
    offlineClock.bootCount--;
    now = now.add(const Duration(days: 7));
    offlineClock.elapsedRealtime += const Duration(days: 7);
    await expectLater(workflow.authorizeCheckout(session), throwsStateError);
    now = DateTime.utc(2026, 9, 28, 12);
    offlineClock.elapsedRealtime = const Duration(hours: 2);
    final credential = await store.read('device-1', 'cashier-1');
    await keys.write('offline-credential:device-1:cashier-1',
        jsonEncode({...credential!.toMap(), 'credentialVersion': 2}));
    await expectLater(workflow.authorizeCheckout(session), throwsStateError);
    await store.save(credential);
    workflow.lockCashier();
    await expectLater(workflow.authorizeCheckout(session), throwsStateError);
    expect(await store.readCheckoutGrant('device-1', 'grant-1'), isNotNull);
  });
  test(
      'observed grant denial removes active offline authority, retaining upload secret',
      () async {
    await workflow.load();
    final session =
        (await workflow.loginCashier('cashier-1', '123456')).session!;
    await workflow.invalidateCheckoutAuthorization(session);
    await expectLater(workflow.authorizeCheckout(session), throwsStateError);
    expect(await store.read('device-1', 'cashier-1'), isNull);
    expect(await store.activeCheckoutGrant('device-1', 'cashier-1'), isNull);
    expect(await store.readCheckoutGrant('device-1', 'grant-1'), isNotNull);
    // An old screen's denial must not invalidate a freshly signed-in cashier.
    final renewed =
        (await workflow.loginCashier('cashier-1', '123456')).session!;
    await workflow.invalidateCheckoutAuthorization(session);
    expect(
        (await workflow.authorizeCheckout(renewed)).scope.grantId, 'grant-1');
  });
  test('legacy credentials and revoked devices cannot authorize payment',
      () async {
    await workflow.load();
    final session =
        (await workflow.loginCashier('cashier-1', '123456')).session!;
    await store.invalidateDeviceAuthorization('device-1');
    await expectLater(workflow.authorizeCheckout(session), throwsStateError);
    expect(await store.readCheckoutGrant('device-1', 'grant-1'), isNotNull);
    await workflow.clearDeviceSession();
    await expectLater(workflow.authorizeCheckout(session), throwsStateError);
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
  test(
      'cached roster is display-only, bounded by gate and cleared on revocation',
      () async {
    await workflow.load();
    expect((await workflow.listCashiers()).single.displayName, 'Ana');
    cashiers.rosterOffline = true;
    expect((await workflow.listCashiers()).single.cashierId, 'cashier-1');
    devices.error =
        FirebaseFunctionsException(code: 'unavailable', message: 'Offline');
    now = now.add(const Duration(days: 8));
    offlineClock.elapsedRealtime += const Duration(days: 8);
    expect(
        (await workflow.load()).state, PosGateState.offlineCredentialsExpired);
    devices.error = FirebaseFunctionsException(
        code: 'permission-denied', message: 'Revoked');
    expect((await workflow.load()).state, PosGateState.deviceRevoked);
    expect(await store.readRoster('device-1'), isEmpty);
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

  for (final missingAttestation in [false, true]) {
    test(
        'HTTPS attestation failure preserves offline context '
        '(missing=$missingAttestation), then revocation clears it', () async {
      var revoked = false;
      final gateway = HttpsMerchantGateway(
        endpoint: Uri.parse('https://api.example.test'),
        environment: SariSupplyEnvironment.dev,
        idToken: () async => 'device-token',
        appCheckToken: () async =>
            missingAttestation && !revoked ? null : 'attestation',
        client: MockClient((request) async => http.Response(
            jsonEncode({
              'error': {
                'code': revoked ? 'permission-denied' : 'unavailable',
                'message':
                    revoked ? 'Device revoked' : 'App verification unavailable',
              }
            }),
            revoked ? 403 : 503)),
      );
      await workflow.load();
      await store.save(StoredOfflineCredential(
        cashierId: 'cashier-1',
        deviceId: 'device-1',
        credentialVersion: 1,
        salt: List.filled(16, 1),
        derivedVerifier: List.filled(32, 2),
        bundleIssuedAt: now,
        bundleExpiresAt: now.add(const Duration(days: 7)),
        lastObservedWallClock: now,
        clockAnchor: null,
        failedAttempts: 0,
        cooldownUntil: null,
      ));
      workflow = FirebasePosWorkflow(
        humanAuth: _TestAuth(null),
        deviceAuth: deviceAuth,
        humanIdentity: _HumanIdentity(),
        applications: _Applications(),
        memberships: _Memberships(),
        devices: DeviceFunctions(
          humanAuth: _TestAuth(null),
          deviceSession: _DeviceSession(),
          humanGateway: gateway,
          deviceGateway: gateway,
        ),
        cashiers: cashiers,
        store: store,
        offlineClock: offlineClock,
        clock: () => now,
      );

      expect(
          (await workflow.load()).state, PosGateState.deviceReadyCashierLocked);
      expect(deviceAuth.currentUser?.uid, 'device:device-1');
      expect(await store.readDeviceContext('device-1'), isNotNull);
      expect(await store.read('device-1', 'cashier-1'), isNotNull);

      revoked = true;
      expect((await workflow.load()).state, PosGateState.deviceRevoked);
      expect(deviceAuth.currentUser, isNull);
      expect(await store.readDeviceContext('device-1'), isNull);
      expect(await store.read('device-1', 'cashier-1'), isNull);
    });
  }

  for (final code in ['permission-denied', 'unauthenticated']) {
    test('$code invalidates authorization before later offline recovery',
        () async {
      await workflow.load();
      await store.save(StoredOfflineCredential(
        cashierId: 'cashier-1',
        deviceId: 'device-1',
        credentialVersion: 1,
        salt: List.filled(16, 1),
        derivedVerifier: List.filled(32, 2),
        bundleIssuedAt: now,
        bundleExpiresAt: now.add(const Duration(days: 7)),
        lastObservedWallClock: now,
        clockAnchor: null,
        failedAttempts: 0,
        cooldownUntil: null,
      ));
      await store.queueFailedAttempt(
          deviceId: 'device-1',
          cashierId: 'cashier-1',
          failedAttempts: 5,
          occurredAt: now);
      final event = (await store.queuedSecurityEvents('device-1')).single;
      devices.error =
          FirebaseFunctionsException(code: code, message: 'Revoked');

      expect((await workflow.load()).state, PosGateState.deviceRevoked);
      expect(await store.readDeviceContext('device-1'), isNull);
      expect(await store.read('device-1', 'cashier-1'), isNull);
      expect(deviceAuth.currentUser, isNull);
      expect((await store.queuedSecurityEvents('device-1')).single, event);
      devices.error =
          FirebaseFunctionsException(code: 'unavailable', message: 'Offline');
      expect((await workflow.load()).state, PosGateState.signedOut);
    });
  }

  test('failed device sign-out cannot restore revoked offline context',
      () async {
    await workflow.load();
    deviceAuth.signOutFails = true;
    devices.error = FirebaseFunctionsException(
        code: 'permission-denied', message: 'Revoked');
    expect((await workflow.load()).state, PosGateState.deviceRevoked);
    expect(await store.readDeviceContext('device-1'), isNull);
    devices.error =
        FirebaseFunctionsException(code: 'unavailable', message: 'Offline');
    expect(
        (await workflow.load()).state, PosGateState.offlineCredentialsExpired);
  });

  for (final corruption in <String, Object?>{
    'cashierId': 123,
    'failedAttempts': 'five',
    'occurredAt': 456,
  }.entries) {
    test('malformed ${corruption.key} does not block bootstrap or online login',
        () async {
      const key = 'offline-event:device-1:corrupt-event-12345678';
      final encoded = jsonEncode({
        'type': 'offline_pin_failed',
        'eventId': 'corrupt-event-12345678',
        'cashierId': 'cashier-1',
        'failedAttempts': 5,
        'occurredAt': now.toIso8601String(),
        corruption.key: corruption.value,
      });
      keys.values[key] = encoded;
      expect(
          (await workflow.load()).state, PosGateState.deviceReadyCashierLocked);
      expect((await workflow.loginCashier('cashier-1', '123456')).status,
          CashierLoginStatus.signedIn);
      expect(keys.values[key], encoded);
      expect(await store.hasSecurityEventCapacity('device-1'), isFalse);
    });
  }

  test('partial audit acknowledgement cannot block bootstrap or cashier login',
      () async {
    await store.queueFailedAttempt(
        deviceId: 'device-1',
        cashierId: 'cashier-1',
        failedAttempts: 5,
        occurredAt: now);
    final event = (await store.queuedSecurityEvents('device-1')).single;
    cashiers.partialAcknowledgement = true;
    expect(
        (await workflow.load()).state, PosGateState.deviceReadyCashierLocked);
    expect((await workflow.loginCashier('cashier-1', '123456')).status,
        CashierLoginStatus.signedIn);
    expect((await store.queuedSecurityEvents('device-1')).single, event);
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
