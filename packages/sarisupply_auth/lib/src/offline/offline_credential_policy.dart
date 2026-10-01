import 'package:sarisupply_models/sarisupply_models.dart';

import 'offline_credential.dart';

enum OfflineCredentialDecision {
  allowed,
  requiresOnlineRefresh,
  requiresOnlineReenrollment,
}

/// Sampled from Android elapsed realtime, which includes deep sleep.
final class OfflineClockReading {
  const OfflineClockReading(
      {required this.bootCount, required this.elapsedRealtime});

  final int bootCount;
  final Duration elapsedRealtime;
}

/// Persisted only when an online credential bundle has been verified.
final class OfflineClockAnchor {
  const OfflineClockAnchor(
      {required this.wallClock,
      required this.bootCount,
      required this.elapsedRealtime});

  final DateTime wallClock;
  final int bootCount;
  final Duration elapsedRealtime;
}

final class OfflineTimeEvidence {
  const OfflineTimeEvidence(
      {required this.now,
      required this.lastObservedWallClock,
      required this.anchor,
      required this.reading});

  final DateTime now;
  final DateTime lastObservedWallClock;
  final OfflineClockAnchor? anchor;
  final OfflineClockReading? reading;
}

abstract final class OfflineCredentialPolicy {
  static const maximumOfflineAge = Duration(days: 7);
  static const maximumClockRollback = Duration(minutes: 5);

  static OfflineCredentialDecision evaluate(
    OfflineCredential credential,
    OfflineTimeEvidence time,
    int serverCredentialVersion,
  ) {
    if (credential.credentialVersion != serverCredentialVersion) {
      return OfflineCredentialDecision.requiresOnlineReenrollment;
    }

    final anchor = time.anchor;
    final reading = time.reading;
    if (credential.cashierStatus != CashierStatus.active ||
        credential.mustChangePin ||
        !credential.bundleExpiresAt.isAfter(credential.bundleIssuedAt) ||
        credential.bundleExpiresAt.difference(credential.bundleIssuedAt) >
            maximumOfflineAge ||
        time.now.isBefore(credential.bundleIssuedAt) ||
        !time.now.isBefore(credential.bundleExpiresAt) ||
        time.now.isBefore(
            time.lastObservedWallClock.subtract(maximumClockRollback)) ||
        anchor == null ||
        reading == null ||
        anchor.bootCount < 0 ||
        reading.bootCount < 0 ||
        anchor.bootCount != reading.bootCount ||
        anchor.elapsedRealtime.isNegative ||
        reading.elapsedRealtime < anchor.elapsedRealtime) {
      return OfflineCredentialDecision.requiresOnlineRefresh;
    }

    final elapsed = reading.elapsedRealtime - anchor.elapsedRealtime;
    final wallElapsed = time.now.difference(anchor.wallClock);
    final drift = wallElapsed - elapsed;
    if (elapsed >= maximumOfflineAge ||
        elapsed >= credential.bundleExpiresAt.difference(anchor.wallClock) ||
        drift > maximumClockRollback ||
        drift < -maximumClockRollback ||
        anchor.wallClock.isBefore(credential.bundleIssuedAt) ||
        !anchor.wallClock.isBefore(credential.bundleExpiresAt)) {
      return OfflineCredentialDecision.requiresOnlineRefresh;
    }

    return OfflineCredentialDecision.allowed;
  }
}
