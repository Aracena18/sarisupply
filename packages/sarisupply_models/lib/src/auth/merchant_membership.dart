import 'auth_enums.dart';

final class MerchantMembership {
  MerchantMembership({
    required this.userId,
    required this.merchantId,
    required this.role,
    required this.status,
    required this.allBranches,
    required List<String> branchIds,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    this.merchantName = 'Store',
  }) : branchIds = List.unmodifiable(branchIds);

  factory MerchantMembership.fromMap(Map<String, Object?> map) =>
      MerchantMembership(
        userId: map['userId'] as String,
        merchantId: map['merchantId'] as String,
        role: MerchantRole.fromWireValue(map['role'] as String),
        status: MembershipStatus.fromWireValue(map['status'] as String),
        allBranches: map['allBranches'] as bool,
        branchIds: List<String>.from(map['branchIds'] as List),
        createdAt: map['createdAt'] as DateTime,
        createdBy: map['createdBy'] as String,
        updatedAt: map['updatedAt'] as DateTime,
        merchantName: map['merchantName'] as String? ?? 'Store',
      );

  final String userId;
  final String merchantId;
  final MerchantRole role;
  final MembershipStatus status;
  final bool allBranches;
  final List<String> branchIds;
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String merchantName;

  Map<String, Object?> toMap() => {
        'userId': userId,
        'merchantId': merchantId,
        'role': role.wireValue,
        'status': status.wireValue,
        'allBranches': allBranches,
        'branchIds': branchIds,
        'createdAt': createdAt,
        'createdBy': createdBy,
        'updatedAt': updatedAt,
      };
}
