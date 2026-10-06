import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/cashier_auth/data/secure_offline_credential_store.dart';

class Keys implements SecureKeyValueStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String k) async => data[k];
  @override
  Future<void> write(String k, String v) async {
    data[k] = v;
  }

  @override
  Future<void> delete(String k) async {
    data.remove(k);
  }

  @override
  Future<Map<String, String>> readAll() async => Map.of(data);
}

IssuedCashierGrant grant(String id) => IssuedCashierGrant(
    scope: CheckoutScope(
        merchantId: 'm',
        branchId: 'b',
        deviceId: 'd',
        cashierId: 'c',
        grantId: id,
        credentialVersion: 1),
    secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    issuedAt: DateTime.utc(2026, 10, 5),
    expiresAt: DateTime.utc(2026, 10, 12));
void main() {
  test('renewal retains old secrets but invalidation removes active authority',
      () async {
    final keys = Keys();
    final store = SecureOfflineCredentialStore(keys);
    await store.saveCheckoutGrant(grant('old'));
    await store.saveCheckoutGrant(grant('new'));
    expect((await store.activeCheckoutGrant('d', 'c'))!.scope.grantId, 'new');
    expect((await store.readCheckoutGrant('d', 'old'))!.scope.grantId, 'old');
    expect(grant('old').scope.toMap().toString(), isNot(contains('secret')));
    expect(grant('old').toString(), isNot(contains(grant('old').secret)));
    await store.invalidateDeviceAuthorization('d');
    expect(await store.activeCheckoutGrant('d', 'c'), isNull);
    expect(await store.readCheckoutGrant('d', 'old'), isNotNull);
  });
  test('grant lifetime is bounded', () {
    expect(
        () => IssuedCashierGrant(
            scope: grant('g').scope,
            secret: grant('g').secret,
            issuedAt: DateTime.utc(2026, 10, 5),
            expiresAt: DateTime.utc(2026, 10, 13)),
        throwsArgumentError);
  });
}
