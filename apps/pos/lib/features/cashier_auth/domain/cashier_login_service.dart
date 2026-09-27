import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import '../data/local_pin_verifier.dart';
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
  })  : _cashiers = cashiers,
        _store = store,
        _deviceId = deviceId,
        _clock = clock ?? DateTime.now;

  final CashierRepository _cashiers;
  final SecureOfflineCredentialStore _store;
  final String _deviceId;
  final DateTime Function() _clock;

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
        !cashier.mustChangePin);
    if (matching.isEmpty) {
      return const CashierLoginResult(CashierLoginStatus.requiresOnlineRefresh);
    }
    final salt = LocalPinVerifier.generateSalt();
    final verifier = await LocalPinVerifier.derive(pin, salt);
    final now = _clock();
    final record = StoredOfflineCredential(
      cashierId: cashierId,
      deviceId: _deviceId,
      credentialVersion: verified.credentialVersion,
      salt: salt,
      derivedVerifier: verifier,
      bundleIssuedAt: bundle.issuedAt,
      bundleExpiresAt: bundle.expiresAt,
      lastObservedWallClock: now,
      failedAttempts: 0,
      cooldownUntil: null,
    );
    final decision = OfflineCredentialPolicy.evaluate(
      _policyCredential(record),
      now,
      now,
      verified.credentialVersion,
    );
    if (decision != OfflineCredentialDecision.allowed) {
      return const CashierLoginResult(CashierLoginStatus.requiresOnlineRefresh);
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
    final decision = OfflineCredentialPolicy.evaluate(
      _policyCredential(record),
      now,
      record.lastObservedWallClock,
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

  Future<void> _applyBundle(CashierCredentialBundle bundle) async {
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
        lastObservedWallClock: _clock(),
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
