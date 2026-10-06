import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import '../data/local_pin_verifier.dart';
import '../data/offline_clock_source.dart';
import '../data/secure_offline_credential_store.dart';

enum CashierLoginStatus {
  signedIn,
  requiresPinChange,
  requiresOnlineRefresh,
  requiresOnlineReenrollment,
  invalidPin,
  cooldown,
}

final class CashierSession {
  const CashierSession({
    required this.cashierId,
    required this.deviceId,
    required this.startedAt,
  });

  final String cashierId;
  final String deviceId;
  final DateTime startedAt;
}

final class CashierLoginResult {
  const CashierLoginResult(this.status, {this.session});
  final CashierLoginStatus status;
  final CashierSession? session;
}

final class CashierLoginService {
  CashierLoginService({
    required CashierRepository cashiers,
    required SecureOfflineCredentialStore store,
    required String deviceId,
    DateTime Function()? clock,
    OfflineClockSource? offlineClock,
  })  : _cashiers = cashiers,
        _store = store,
        _deviceId = deviceId,
        _clock = clock ?? DateTime.now,
        _offlineClock = offlineClock ?? const AndroidOfflineClockSource();

  final CashierRepository _cashiers;
  final SecureOfflineCredentialStore _store;
  final String _deviceId;
  final DateTime Function() _clock;
  final OfflineClockSource _offlineClock;

  CashierLoginResult _signedIn(String cashierId) => CashierLoginResult(
        CashierLoginStatus.signedIn,
        session: CashierSession(
          cashierId: cashierId,
          deviceId: _deviceId,
          startedAt: _clock(),
        ),
      );

  Future<CashierLoginResult> loginOnline(String cashierId, String pin) async {
    final verified = await _cashiers.verifyPin(cashierId, pin);
    if (verified.mustChangePin) {
      await _store.delete(_deviceId, cashierId);
      return const CashierLoginResult(CashierLoginStatus.requiresPinChange);
    }
    final bundle = await _cashiers.refreshCredentialBundle();
    await _applyBundle(bundle);
    final matching = bundle.cashiers.where((cashier) =>
        cashier.cashierId == cashierId &&
        cashier.credentialVersion == verified.credentialVersion &&
        cashier.status == 'active' &&
        cashier.assignedBranchIds.contains(bundle.branchId) &&
        !cashier.mustChangePin);
    if (matching.isEmpty) {
      return const CashierLoginResult(CashierLoginStatus.requiresOnlineRefresh);
    }
    final salt = LocalPinVerifier.generateSalt();
    final verifier = await LocalPinVerifier.derive(pin, salt);
    final reading = await _offlineClock.read();
    final now = _clock();
    if (reading == null) {
      await _store.delete(_deviceId, cashierId);
      return _signedIn(cashierId);
    }
    final anchor = OfflineClockAnchor(
      wallClock: now,
      bootCount: reading.bootCount,
      elapsedRealtime: reading.elapsedRealtime,
    );
    final record = StoredOfflineCredential(
      cashierId: cashierId,
      deviceId: _deviceId,
      credentialVersion: verified.credentialVersion,
      salt: salt,
      derivedVerifier: verifier,
      bundleIssuedAt: bundle.issuedAt,
      bundleExpiresAt: bundle.expiresAt,
      lastObservedWallClock: now,
      clockAnchor: anchor,
      failedAttempts: 0,
      cooldownUntil: null,
    );
    final decision = OfflineCredentialPolicy.evaluate(
      _policyCredential(record),
      OfflineTimeEvidence(
          now: now,
          lastObservedWallClock: now,
          anchor: anchor,
          reading: reading),
      verified.credentialVersion,
    );
    if (decision != OfflineCredentialDecision.allowed) {
      return const CashierLoginResult(CashierLoginStatus.requiresOnlineRefresh);
    }
    final grant = verified.grant;
    if (grant != null) {
      final context = await _store.readDeviceContext(_deviceId);
      if (grant.scope.deviceId != _deviceId ||
          grant.scope.cashierId != cashierId ||
          grant.scope.credentialVersion != verified.credentialVersion ||
          grant.scope.merchantId != bundle.merchantId ||
          grant.scope.branchId != bundle.branchId ||
          context?.merchantId != bundle.merchantId ||
          context?.branchId != bundle.branchId ||
          now.isBefore(grant.issuedAt) ||
          !now.isBefore(grant.expiresAt)) {
        await _store.delete(_deviceId, cashierId);
        return const CashierLoginResult(
            CashierLoginStatus.requiresOnlineRefresh);
      }
      await _store.saveCheckoutGrant(grant);
    } else {
      // A legacy verification cannot revive a previously issued financial grant.
      await _store.delete(_deviceId, cashierId);
    }
    await _store.save(record);
    return _signedIn(cashierId);
  }

  Future<CashierLoginResult> loginOffline(String cashierId, String pin) async {
    final record = await _store.read(_deviceId, cashierId);
    if (record == null) {
      return const CashierLoginResult(
          CashierLoginStatus.requiresOnlineReenrollment);
    }
    final now = _clock();
    final reading = await _offlineClock.read();
    final decision = OfflineCredentialPolicy.evaluate(
      _policyCredential(record),
      OfflineTimeEvidence(
          now: now,
          lastObservedWallClock: record.lastObservedWallClock,
          anchor: record.clockAnchor,
          reading: reading),
      record.credentialVersion,
    );
    if (decision == OfflineCredentialDecision.requiresOnlineReenrollment) {
      return const CashierLoginResult(
          CashierLoginStatus.requiresOnlineReenrollment);
    }
    if (decision != OfflineCredentialDecision.allowed) {
      return const CashierLoginResult(CashierLoginStatus.requiresOnlineRefresh);
    }
    if (record.cooldownUntil != null && now.isBefore(record.cooldownUntil!)) {
      return const CashierLoginResult(CashierLoginStatus.cooldown);
    }
    if (!await _store.hasSecurityEventCapacity(_deviceId)) {
      return const CashierLoginResult(CashierLoginStatus.requiresOnlineRefresh);
    }

    bool matches;
    try {
      matches = await LocalPinVerifier.matches(
          pin, record.salt, record.derivedVerifier);
    } on ArgumentError {
      matches = false;
    }
    if (!matches) {
      final failures = record.failedAttempts + 1;
      final delay = _cooldownForFailure(failures);
      await _store.save(record.copyWith(
        lastObservedWallClock: now,
        failedAttempts: failures,
        cooldownUntil: delay == Duration.zero ? null : now.add(delay),
        clearCooldown: delay == Duration.zero,
      ));
      if (failures >= 5) {
        await _store.queueFailedAttempt(
          deviceId: _deviceId,
          cashierId: cashierId,
          failedAttempts: failures,
          occurredAt: now,
        );
      }
      return const CashierLoginResult(CashierLoginStatus.invalidPin);
    }
    await _store.save(record.copyWith(
      lastObservedWallClock: now,
      failedAttempts: 0,
      clearCooldown: true,
    ));
    return _signedIn(cashierId);
  }

  Future<void> refreshEnrollment() async {
    final bundle = await _cashiers.refreshCredentialBundle();
    await _applyBundle(bundle);
  }

  Future<void> syncQueuedSecurityEvents() async {
    final queued = (await _store.queuedSecurityEvents(_deviceId))
        .where((event) => event['type'] == 'offline_pin_failed')
        .toList();
    for (var start = 0; start < queued.length; start += 20) {
      final batch = queued
          .skip(start)
          .take(20)
          .map((event) => OfflinePinFailureEvent(
                eventId: event['eventId'] as String,
                cashierId: event['cashierId'] as String,
                failedAttempts: event['failedAttempts'] as int,
                occurredAt: DateTime.parse(event['occurredAt'] as String),
              ))
          .toList();
      final accepted = await _cashiers.reportOfflinePinFailures(batch);
      final batchIds = batch.map((event) => event.eventId).toSet();
      if (!accepted.toSet().containsAll(batchIds)) {
        throw StateError('Offline security events were not acknowledged');
      }
      await _store.acknowledgeSecurityEvents(_deviceId, batchIds.toList());
    }
  }

  Future<void> _applyBundle(CashierCredentialBundle bundle) async {
    final reading = await _offlineClock.read();
    final now = _clock();
    final anchor = reading == null
        ? null
        : OfflineClockAnchor(
            wallClock: now,
            bootCount: reading.bootCount,
            elapsedRealtime: reading.elapsedRealtime,
          );
    final current = await _store.listForDevice(_deviceId);
    final projections = {
      for (final cashier in bundle.cashiers) cashier.cashierId: cashier,
    };
    for (final credential in current) {
      final projection = projections[credential.cashierId];
      if (projection == null ||
          projection.status != 'active' ||
          projection.mustChangePin ||
          projection.credentialVersion != credential.credentialVersion) {
        await _store.delete(_deviceId, credential.cashierId);
        continue;
      }
      await _store.save(credential.copyWith(
        bundleIssuedAt: bundle.issuedAt,
        bundleExpiresAt: bundle.expiresAt,
        lastObservedWallClock: now,
        clockAnchor: anchor,
        clearClockAnchor: anchor == null,
      ));
    }
  }

  static OfflineCredential _policyCredential(StoredOfflineCredential record) =>
      OfflineCredential(
        cashierId: record.cashierId,
        deviceId: record.deviceId,
        credentialVersion: record.credentialVersion,
        cashierStatus: CashierStatus.active,
        mustChangePin: false,
        bundleIssuedAt: record.bundleIssuedAt,
        bundleExpiresAt: record.bundleExpiresAt,
      );

  static Duration _cooldownForFailure(int failures) {
    if (failures < 5) return Duration.zero;
    final seconds = 30 * (1 << (failures - 5).clamp(0, 5));
    return Duration(seconds: seconds > 900 ? 900 : seconds);
  }
}
