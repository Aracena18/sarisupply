import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

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
  IssuedCashierGrant? grant;
  bool mustChangePin = false;
  int version = 1;
  DateTime now = DateTime.utc(2026, 9, 27);
  bool reportFails = false;
  bool partialReport = false;
  List<OfflinePinFailureEvent> reported = [];
  final batchSizes = <int>[];

  @override
  Future<List<String>> reportOfflinePinFailures(
      List<OfflinePinFailureEvent> events) async {
    if (reportFails) throw StateError('Upload failed');
    batchSizes.add(events.length);
    reported = [...reported, ...events];
    if (partialReport) return [events.first.eventId];
    return events.map((event) => event.eventId).toList();
  }

  @override
  Future<CashierPinVerification> verifyPin(String cashierId, String pin) async {
    if (pin != '123456') throw StateError('Server rejected PIN');
    return CashierPinVerification(
      cashierId: cashierId,
      credentialVersion: version,
      mustChangePin: mustChangePin,
      grant: grant,
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

  test(
      'grant cache checks bundle binding and retains older grant for pending work',
      () async {
    await store.saveDeviceContext(StoredDeviceContext(
        deviceId: 'device-1',
        merchantId: 'merchant-1',
        branchId: 'branch-a',
        verifiedAt: now,
        lastObservedWallClock: now,
        clockAnchor: null));
    IssuedCashierGrant issued(String id, {String branch = 'branch-a'}) =>
        IssuedCashierGrant(
            scope: CheckoutScope(
                merchantId: 'merchant-1',
                branchId: branch,
                deviceId: 'device-1',
                cashierId: 'cashier-1',
                grantId: id,
                credentialVersion: 1),
            secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
            issuedAt: server.now,
            expiresAt: server.now.add(const Duration(days: 7)));
    server.grant = issued('old');
    expect((await service.loginOnline('cashier-1', '123456')).status,
        CashierLoginStatus.signedIn);
    server.grant = issued('new');
    await service.loginOnline('cashier-1', '123456');
    expect(
        (await store.activeCheckoutGrant('device-1', 'cashier-1'))!
            .scope
            .grantId,
        'new');
    expect(await store.readCheckoutGrant('device-1', 'old'), isNotNull);
    server.grant = issued('foreign', branch: 'other');
    expect((await service.loginOnline('cashier-1', '123456')).status,
        CashierLoginStatus.requiresOnlineRefresh);
    expect(await store.activeCheckoutGrant('device-1', 'cashier-1'), isNull);
    expect(await store.readCheckoutGrant('device-1', 'foreign'), isNull);
    expect(await store.readCheckoutGrant('device-1', 'old'), isNotNull);
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

  test('retains queued events and refuses to silently overflow the queue',
      () async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await store.queueFailedAttempt(
        deviceId: 'device-1',
        cashierId: 'cashier-1',
        failedAttempts: attempt + 5,
        occurredAt: now.add(Duration(seconds: attempt)),
      );
    }

    await expectLater(
      store.queueFailedAttempt(
        deviceId: 'device-1',
        cashierId: 'cashier-1',
        failedAttempts: 205,
        occurredAt: now.add(const Duration(seconds: 200)),
      ),
      throwsStateError,
    );
    final events = await store.queuedSecurityEvents('device-1');
    expect(events, hasLength(200));
    expect(events.map((event) => event['eventId']).toSet(), hasLength(200));
  });

  test('a full security queue requires refresh before another offline PIN',
      () async {
    await service.loginOnline('cashier-1', '123456');
    for (var attempt = 0; attempt < 200; attempt++) {
      await store.queueFailedAttempt(
        deviceId: 'device-1',
        cashierId: 'cashier-1',
        failedAttempts: attempt + 5,
        occurredAt: now.add(Duration(seconds: attempt)),
      );
    }

    expect((await service.loginOffline('cashier-1', '000000')).status,
        CashierLoginStatus.requiresOnlineRefresh);
    expect((await store.queuedSecurityEvents('device-1')), hasLength(200));
    expect((await store.read('device-1', 'cashier-1'))?.failedAttempts, 0);
  });

  test('legacy queued events receive a stable id before upload', () async {
    keys.values['offline-events:device-1'] = jsonEncode([
      {
        'type': 'offline_pin_failed',
        'cashierId': 'cashier-1',
        'failedAttempts': 5,
        'occurredAt': now.toIso8601String(),
      }
    ]);

    final firstRead = await store.queuedSecurityEvents('device-1');
    final secondRead = await store.queuedSecurityEvents('device-1');

    expect(firstRead.single['eventId'], isA<String>());
    expect(secondRead.single['eventId'], firstRead.single['eventId']);
  });

  test('resumes an interrupted legacy event migration without duplication',
      () async {
    const eventId = 'legacy-event-1234567890';
    final event = {
      'type': 'offline_pin_failed',
      'eventId': eventId,
      'cashierId': 'cashier-1',
      'failedAttempts': 5,
      'occurredAt': now.toIso8601String(),
    };
    keys.values['offline-events:device-1'] = jsonEncode([event]);
    keys.values['offline-event:device-1:$eventId'] = jsonEncode(event);

    final queued = await store.queuedSecurityEvents('device-1');

    expect(queued, hasLength(1));
    expect(queued.single['eventId'], eventId);
    expect(keys.values, isNot(contains('offline-events:device-1')));
  });

  test('failed event uploads stay queued and are removed after acknowledgement',
      () async {
    await store.queueFailedAttempt(
      deviceId: 'device-1',
      cashierId: 'cashier-1',
      failedAttempts: 5,
      occurredAt: now,
    );
    final eventId = (await store.queuedSecurityEvents('device-1'))
        .single['eventId']! as String;
    server.reportFails = true;

    await expectLater(service.syncQueuedSecurityEvents(), throwsStateError);
    expect(await store.queuedSecurityEvents('device-1'), hasLength(1));

    server.reportFails = false;
    await service.syncQueuedSecurityEvents();
    expect(server.reported.single.eventId, eventId);
    expect(server.reported.single.cashierId, 'cashier-1');
    expect(await store.queuedSecurityEvents('device-1'), isEmpty);
  });

  test(
      'offline event uploads stay queued when the server acknowledges only part',
      () async {
    for (var attempt = 0; attempt < 2; attempt++) {
      await store.queueFailedAttempt(
        deviceId: 'device-1',
        cashierId: 'cashier-1',
        failedAttempts: attempt + 5,
        occurredAt: now.add(Duration(seconds: attempt)),
      );
    }
    server.partialReport = true;

    await expectLater(service.syncQueuedSecurityEvents(), throwsStateError);
    expect(await store.queuedSecurityEvents('device-1'), hasLength(2));
  });

  for (final corruption in <String, Object?>{
    'cashierId': 123,
    'failedAttempts': 'five',
    'occurredAt': 'not-a-date',
    'type': 'unknown',
  }.entries) {
    test('malformed ${corruption.key} stays quarantined and blocks offline PIN',
        () async {
      await service.loginOnline('cashier-1', '123456');
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
      await service.syncQueuedSecurityEvents();
      expect(server.reported, isEmpty);
      expect(await store.queuedSecurityEvents('device-1'), isEmpty);
      expect(keys.values[key], encoded);
      expect((await service.loginOffline('cashier-1', '123456')).status,
          CashierLoginStatus.requiresOnlineRefresh);
    });
  }

  test('malformed legacy records stay intact without blocking online sync',
      () async {
    const key = 'offline-events:device-1';
    final encoded = jsonEncode([
      {
        'type': 'offline_pin_failed',
        'cashierId': 123,
        'failedAttempts': 5,
        'occurredAt': now.toIso8601String(),
      }
    ]);
    keys.values[key] = encoded;
    await service.syncQueuedSecurityEvents();
    expect(keys.values[key], encoded);
    expect(server.reported, isEmpty);
    expect(await store.hasSecurityEventCapacity('device-1'), isFalse);
  });

  test('legacy migration cannot acknowledge a colliding quarantined record',
      () async {
    const eventId = 'colliding-event-12345678';
    const key = 'offline-event:device-1:$eventId';
    final valid = {
      'type': 'offline_pin_failed',
      'eventId': eventId,
      'cashierId': 'cashier-1',
      'failedAttempts': 5,
      'occurredAt': now.toIso8601String(),
    };
    final corrupt = jsonEncode({...valid, 'cashierId': 123});
    keys.values[key] = corrupt;
    keys.values['offline-events:device-1'] = jsonEncode([valid]);
    await service.syncQueuedSecurityEvents();
    expect(server.reported.single.eventId, isNot(eventId));
    expect(server.reported.single.cashierId, 'cashier-1');
    expect(keys.values[key], corrupt);
    expect(await store.hasSecurityEventCapacity('device-1'), isFalse);
  });

  test('healthy events sync while a malformed record remains quarantined',
      () async {
    await store.queueFailedAttempt(
        deviceId: 'device-1',
        cashierId: 'cashier-1',
        failedAttempts: 5,
        occurredAt: now);
    final healthyId =
        (await store.queuedSecurityEvents('device-1')).single['eventId'];
    const key = 'offline-event:device-1:corrupt-event-12345678';
    final encoded = jsonEncode({
      'type': 'offline_pin_failed',
      'eventId': 'corrupt-event-12345678',
      'cashierId': 123,
      'failedAttempts': 5,
      'occurredAt': now.toIso8601String(),
    });
    keys.values[key] = encoded;
    await service.syncQueuedSecurityEvents();
    expect(server.reported.single.eventId, healthyId);
    expect(await store.queuedSecurityEvents('device-1'), isEmpty);
    expect(keys.values[key], encoded);
    expect(await store.hasSecurityEventCapacity('device-1'), isFalse);
  });

  test('offline event uploads respect the server batch size', () async {
    for (var attempt = 0; attempt < 23; attempt++) {
      await store.queueFailedAttempt(
        deviceId: 'device-1',
        cashierId: 'cashier-1',
        failedAttempts: attempt + 5,
        occurredAt: now.add(Duration(seconds: attempt)),
      );
    }

    await service.syncQueuedSecurityEvents();

    expect(server.batchSizes, [20, 3]);
    expect(await store.queuedSecurityEvents('device-1'), isEmpty);
  });
}
