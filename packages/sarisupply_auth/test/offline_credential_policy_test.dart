import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  final issuedAt = DateTime.utc(2026, 9, 20, 12);

  OfflineCredential credential({
    int version = 3,
    CashierStatus status = CashierStatus.active,
    bool mustChangePin = false,
    DateTime? expiresAt,
  }) =>
      OfflineCredential(
        cashierId: 'cashier-1',
        deviceId: 'device-1',
        credentialVersion: version,
        cashierStatus: status,
        mustChangePin: mustChangePin,
        bundleIssuedAt: issuedAt,
        bundleExpiresAt: expiresAt ?? issuedAt.add(const Duration(days: 7)),
      );

  test('valid permanent credential is allowed before seven-day expiry', () {
    final now = issuedAt.add(const Duration(days: 6));

    expect(
      OfflineCredentialPolicy.evaluate(credential(), now, now, 3),
      OfflineCredentialDecision.allowed,
    );
  });

  test('credential expires at the seven-day boundary', () {
    final now = issuedAt.add(const Duration(days: 7));

    expect(
      OfflineCredentialPolicy.evaluate(credential(), now, now, 3),
      OfflineCredentialDecision.requiresOnlineRefresh,
    );
  });

  test('a newer server credential version requires reenrollment', () {
    final now = issuedAt.add(const Duration(days: 1));

    expect(
      OfflineCredentialPolicy.evaluate(credential(), now, now, 4),
      OfflineCredentialDecision.requiresOnlineReenrollment,
    );
  });

  test('suspended cashier cannot use the local verifier', () {
    final now = issuedAt.add(const Duration(days: 1));

    expect(
      OfflineCredentialPolicy.evaluate(
          credential(status: CashierStatus.suspended), now, now, 3),
      OfflineCredentialDecision.requiresOnlineRefresh,
    );
  });

  test('temporary PIN cannot be used offline', () {
    final now = issuedAt.add(const Duration(days: 1));

    expect(
      OfflineCredentialPolicy.evaluate(
          credential(mustChangePin: true), now, now, 3),
      OfflineCredentialDecision.requiresOnlineRefresh,
    );
  });

  test('clock rollback over five minutes requires online refresh', () {
    final observed = issuedAt.add(const Duration(days: 2));

    expect(
      OfflineCredentialPolicy.evaluate(credential(),
          observed.subtract(const Duration(minutes: 6)), observed, 3),
      OfflineCredentialDecision.requiresOnlineRefresh,
    );
  });

  test('expiry metadata cannot extend validity beyond seven days', () {
    final now = issuedAt.add(const Duration(days: 7));

    expect(
      OfflineCredentialPolicy.evaluate(
          credential(expiresAt: issuedAt.add(const Duration(days: 30))),
          now,
          now,
          3),
      OfflineCredentialDecision.requiresOnlineRefresh,
    );
  });
}
