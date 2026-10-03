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

    if (credential.cashierStatus != CashierStatus.active ||
        credential.mustChangePin ||
        !isWithinTrustedWindow(
          issuedAt: credential.bundleIssuedAt,
          expiresAt: credential.bundleExpiresAt,
          time: time,
        )) {
      return OfflineCredentialDecision.requiresOnlineRefresh;
    }

    return OfflineCredentialDecision.allowed;
  }

  /// Validates an offline window against both wall time and a same-boot
  /// monotonic clock sample. Missing or reset elapsed-time evidence fails
  /// closed so callers can require an online refresh.
  static bool isWithinTrustedWindow({
    required DateTime issuedAt,
    required DateTime expiresAt,
    required OfflineTimeEvidence time,
  }) {
    final anchor = time.anchor;
    final reading = time.reading;
    if (!expiresAt.isAfter(issuedAt) ||
        expiresAt.difference(issuedAt) > maximumOfflineAge ||
        time.now.isBefore(issuedAt) ||
        !time.now.isBefore(expiresAt) ||
        time.now.isBefore(
            time.lastObservedWallClock.subtract(maximumClockRollback)) ||
        anchor == null ||
        reading == null ||
        anchor.bootCount < 0 ||
        reading.bootCount < 0 ||
        anchor.bootCount != reading.bootCount ||
        anchor.elapsedRealtime.isNegative ||
        reading.elapsedRealtime < anchor.elapsedRealtime) {
      return false;
    }

    final elapsed = reading.elapsedRealtime - anchor.elapsedRealtime;
    final wallElapsed = time.now.difference(anchor.wallClock);
    final drift = wallElapsed - elapsed;
    if (elapsed >= maximumOfflineAge ||
        elapsed >= expiresAt.difference(anchor.wallClock) ||
        drift > maximumClockRollback ||
        drift < -maximumClockRollback ||
        anchor.wallClock.isBefore(issuedAt) ||
        !anchor.wallClock.isBefore(expiresAt)) {
      return false;
    }

    return true;
  }
}
