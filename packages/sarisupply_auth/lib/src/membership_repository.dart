import 'package:sarisupply_models/sarisupply_models.dart';

final class ManagerInvitation {
  ManagerInvitation({
    required this.inviteId,
    required this.merchantId,
    required this.email,
    required this.allBranches,
    required List<String> branchIds,
    required this.expiresAt,
  }) : branchIds = List.unmodifiable(branchIds);

  final String inviteId;
  final String merchantId;
  final String email;
  final bool allBranches;
  final List<String> branchIds;
  final DateTime expiresAt;
}

abstract interface class MembershipRepository {
  Future<List<MerchantMembership>> listMyMemberships();
  Future<List<Branch>> listAccessibleBranches(MerchantMembership membership);
  Future<List<ManagerInvitation>> listMyInvitations();

  Future<String> createManagerInvitation({
    required String merchantId,
    required String email,
    required bool allBranches,
    required List<String> branchIds,
    required String operationId,
  });

  Future<void> acceptManagerInvitation(String merchantId, String inviteId);
  Future<void> revokeManagerInvitation(String merchantId, String inviteId);
  Future<void> updateManagerAccess({
    required String merchantId,
    required String managerUid,
    required bool allBranches,
    required List<String> branchIds,
  });
  Future<void> removeManager(String merchantId, String managerUid);

  Future<String> createBranch({
    required String merchantId,
    required String name,
    required String code,
    required String address,
    required String operationId,
    Map<String, Object?> contactDetails = const {},
    Map<String, Object?> operatingHours = const {},
  });
  Future<void> deactivateBranch(String merchantId, String branchId);
}
