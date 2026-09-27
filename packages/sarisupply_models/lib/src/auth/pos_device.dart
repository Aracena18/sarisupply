import 'auth_enums.dart';

final class PosDevice {
  const PosDevice({
    required this.id,
    required this.merchantId,
    required this.branchId,
    required this.displayName,
    required this.status,
    required this.activatedAt,
    required this.activatedBy,
    required this.revokedAt,
  });

  factory PosDevice.fromMap(Map<String, Object?> map) => PosDevice(
        id: map['id'] as String,
        merchantId: map['merchantId'] as String,
        branchId: map['branchId'] as String,
        displayName: map['displayName'] as String,
        status: PosDeviceStatus.fromWireValue(map['status'] as String),
        activatedAt: map['activatedAt'] as DateTime,
        activatedBy: map['activatedBy'] as String,
        revokedAt: map['revokedAt'] as DateTime?,
      );

  final String id;
  final String merchantId;
  final String branchId;
  final String displayName;
  final PosDeviceStatus status;
  final DateTime activatedAt;
  final String activatedBy;
  final DateTime? revokedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'merchantId': merchantId,
        'branchId': branchId,
        'displayName': displayName,
        'status': status.wireValue,
        'activatedAt': activatedAt,
        'activatedBy': activatedBy,
        'revokedAt': revokedAt,
      };
}
