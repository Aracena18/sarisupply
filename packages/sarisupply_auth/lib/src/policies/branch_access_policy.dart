import 'package:sarisupply_models/sarisupply_models.dart';

abstract final class BranchAccessPolicy {
  static bool canAccessBranch(MerchantMembership membership, String branchId) {
    if (membership.status != MembershipStatus.active) return false;
    if (branchId.isEmpty) return false;
    if (membership.role == MerchantRole.owner) return true;
    return membership.allBranches || membership.branchIds.contains(branchId);
  }

  static bool canManageManagers(MerchantMembership membership) =>
      membership.status == MembershipStatus.active &&
      membership.role == MerchantRole.owner;

  static bool canCreateOrDeactivateBranch(MerchantMembership membership) =>
      membership.status == MembershipStatus.active &&
      membership.role == MerchantRole.owner;
}
