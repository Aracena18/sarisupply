import 'package:sarisupply_models/sarisupply_models.dart';

import 'offline_credential.dart';

enum OfflineCredentialDecision {
  allowed,
  requiresOnlineRefresh,
  requiresOnlineReenrollment,
}

abstract final class OfflineCredentialPolicy {
  static const maximumOfflineAge = Duration(days: 7);
  static const maximumClockRollback = Duration(minutes: 5);

  static OfflineCredentialDecision evaluate(
    OfflineCredential credential,
    DateTime now,
    DateTime lastObservedWallClock,
    int serverCredentialVersion,
  ) {
    if (credential.credentialVersion != serverCredentialVersion) {
      return OfflineCredentialDecision.requiresOnlineReenrollment;
    }

    if (credential.cashierStatus != CashierStatus.active ||
        credential.mustChangePin ||
        now.isBefore(lastObservedWallClock.subtract(maximumClockRollback)) ||
        now.isBefore(
          credential.bundleIssuedAt.subtract(maximumClockRollback),
        ) ||
        credential.bundleExpiresAt.isAfter(
          credential.bundleIssuedAt.add(maximumOfflineAge),
        ) ||
        !now.isBefore(credential.bundleExpiresAt) ||
        !now.isBefore(credential.bundleIssuedAt.add(maximumOfflineAge))) {
      return OfflineCredentialDecision.requiresOnlineRefresh;
    }

    return OfflineCredentialDecision.allowed;
  }
}
