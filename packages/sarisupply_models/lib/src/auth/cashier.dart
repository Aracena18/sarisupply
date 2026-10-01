import 'auth_enums.dart';

final class Cashier {
  Cashier({
    required this.id,
    required this.merchantId,
    required this.displayName,
    required this.employeeCode,
    required List<String> assignedBranchIds,
    required this.status,
    required this.mustChangePin,
    required this.createdAt,
    required this.updatedAt,
  }) : assignedBranchIds = List.unmodifiable(assignedBranchIds);

  factory Cashier.fromMap(Map<String, Object?> map) => Cashier(
        id: map['id'] as String,
        merchantId: map['merchantId'] as String,
        displayName: map['displayName'] as String,
        employeeCode: map['employeeCode'] as String,
        assignedBranchIds: List<String>.from(map['assignedBranchIds'] as List),
        status: CashierStatus.fromWireValue(map['status'] as String),
        mustChangePin: map['mustChangePin'] as bool,
        createdAt: map['createdAt'] as DateTime,
        updatedAt: map['updatedAt'] as DateTime,
      );

  final String id;
  final String merchantId;
  final String displayName;
  final String employeeCode;
  final List<String> assignedBranchIds;
  final CashierStatus status;
  final bool mustChangePin;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'merchantId': merchantId,
        'displayName': displayName,
        'employeeCode': employeeCode,
        'assignedBranchIds': assignedBranchIds,
        'status': status.wireValue,
        'mustChangePin': mustChangePin,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
