import 'package:sarisupply_models/sarisupply_models.dart';

final class OfflineCredential {
  const OfflineCredential({
    required this.cashierId,
    required this.deviceId,
    required this.credentialVersion,
    required this.cashierStatus,
    required this.mustChangePin,
    required this.bundleIssuedAt,
    required this.bundleExpiresAt,
  });

  final String cashierId;
  final String deviceId;
  final int credentialVersion;
  final CashierStatus cashierStatus;
  final bool mustChangePin;
  final DateTime bundleIssuedAt;
  final DateTime bundleExpiresAt;
}
