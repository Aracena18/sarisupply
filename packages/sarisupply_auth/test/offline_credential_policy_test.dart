import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  final issuedAt = DateTime.utc(2026, 9, 20, 12);

  OfflineCredential credential(
          {int version = 3,
          CashierStatus status = CashierStatus.active,
          bool mustChangePin = false,
          DateTime? expiresAt}) =>
      OfflineCredential(
          cashierId: 'cashier-1',
          deviceId: 'device-1',
          credentialVersion: version,
          cashierStatus: status,
          mustChangePin: mustChangePin,
          bundleIssuedAt: issuedAt,
          bundleExpiresAt: expiresAt ?? issuedAt.add(const Duration(days: 7)));

  OfflineTimeEvidence evidence(
          {Duration elapsed = const Duration(days: 1),
          DateTime? now,
          DateTime? lastObserved,
          int anchorBoot = 4,
          int currentBoot = 4,
          Duration anchorUptime = const Duration(hours: 2),
          Duration? currentUptime,
          bool hasAnchor = true,
          bool hasReading = true}) =>
      OfflineTimeEvidence(
          now: now ?? issuedAt.add(elapsed),
          lastObservedWallClock: lastObserved ?? issuedAt,
          anchor: hasAnchor
              ? OfflineClockAnchor(
                  wallClock: issuedAt,
                  bootCount: anchorBoot,
                  elapsedRealtime: anchorUptime)
              : null,
          reading: hasReading
              ? OfflineClockReading(
                  bootCount: currentBoot,
                  elapsedRealtime: currentUptime ?? anchorUptime + elapsed)
              : null);

  OfflineCredentialDecision check(OfflineTimeEvidence time,
          {OfflineCredential? bundle, int version = 3}) =>
      OfflineCredentialPolicy.evaluate(bundle ?? credential(), time, version);

  test('valid permanent credential is allowed before seven-day expiry', () {
    expect(check(evidence(elapsed: const Duration(days: 6))),
        OfflineCredentialDecision.allowed);
  });

  test('exactly seven days requires online refresh', () {
    expect(check(evidence(elapsed: const Duration(days: 7))),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('elapsed time beyond seven days denies with a held-back wall clock', () {
    expect(
        check(evidence(
            elapsed: const Duration(days: 8),
            now: issuedAt.add(const Duration(days: 1)))),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('a newer server credential version requires reenrollment', () {
    expect(check(evidence(), version: 4),
        OfflineCredentialDecision.requiresOnlineReenrollment);
  });

  test('suspended cashier and temporary PIN are denied', () {
    expect(
        check(evidence(), bundle: credential(status: CashierStatus.suspended)),
        OfflineCredentialDecision.requiresOnlineRefresh);
    expect(check(evidence(), bundle: credential(mustChangePin: true)),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('rollback behind last observation is denied', () {
    expect(check(evidence(lastObserved: issuedAt.add(const Duration(days: 2)))),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('wall clock manipulation backward and forward is denied', () {
    expect(
        check(evidence(
            elapsed: const Duration(days: 2),
            now: issuedAt.add(const Duration(days: 1)))),
        OfflineCredentialDecision.requiresOnlineRefresh);
    expect(
        check(evidence(
            elapsed: const Duration(days: 1),
            now: issuedAt.add(const Duration(days: 2)))),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('reboot and monotonic reset require online refresh', () {
    expect(check(evidence(currentBoot: 5)),
        OfflineCredentialDecision.requiresOnlineRefresh);
    expect(check(evidence(currentUptime: const Duration(minutes: 1))),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('missing or invalid monotonic evidence requires online refresh', () {
    expect(check(evidence(hasAnchor: false)),
        OfflineCredentialDecision.requiresOnlineRefresh);
    expect(check(evidence(hasReading: false)),
        OfflineCredentialDecision.requiresOnlineRefresh);
    expect(check(evidence(anchorBoot: -1)),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('expiry metadata cannot extend validity beyond seven days', () {
    expect(
        check(evidence(),
            bundle:
                credential(expiresAt: issuedAt.add(const Duration(days: 30)))),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('shorter server expiry is enforced by elapsed time despite wall drift',
      () {
    expect(
        check(
            evidence(
              elapsed: const Duration(days: 1, minutes: 1),
              now: issuedAt.add(const Duration(hours: 23, minutes: 59)),
            ),
            bundle:
                credential(expiresAt: issuedAt.add(const Duration(days: 1)))),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('zero-length credential window is denied', () {
    expect(check(evidence(), bundle: credential(expiresAt: issuedAt)),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('reversed window at 12:00 to 11:59 is denied at 11:58', () {
    expect(
        check(evidence(now: issuedAt.subtract(const Duration(minutes: 2))),
            bundle: credential(
                expiresAt: issuedAt.subtract(const Duration(minutes: 1)))),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });

  test('a check before issuance is denied', () {
    expect(check(evidence(now: issuedAt.subtract(const Duration(minutes: 1)))),
        OfflineCredentialDecision.requiresOnlineRefresh);
  });
}
