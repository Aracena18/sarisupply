import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

import 'package:sarisupply_pos/features/cashier_auth/data/secure_offline_credential_store.dart';
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

void main() {
  late _MemoryKeys keys;
  late SecureOfflineCredentialStore store;
  late _Cashiers server;
  late DateTime now;
  late CashierLoginService service;

  setUp(() {
    keys = _MemoryKeys();
    store = SecureOfflineCredentialStore(keys);
    server = _Cashiers();
    now = DateTime.utc(2026, 9, 27, 12);
    service = CashierLoginService(
      cashiers: server,
      store: store,
      deviceId: 'device-1',
      clock: () => now,
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
}
