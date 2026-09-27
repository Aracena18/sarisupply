import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  MerchantMembership membership({
    MerchantRole role = MerchantRole.manager,
    MembershipStatus status = MembershipStatus.active,
    bool allBranches = false,
    List<String> branchIds = const ['branch-a'],
  }) =>
      MerchantMembership(
        userId: 'user-1',
        merchantId: 'merchant-1',
        role: role,
        status: status,
        allBranches: allBranches,
        branchIds: branchIds,
        createdAt: DateTime.utc(2026, 9, 27),
        createdBy: 'owner-1',
        updatedAt: DateTime.utc(2026, 9, 27),
      );

  test('active owner can access any branch and manage structure', () {
    final owner = membership(role: MerchantRole.owner);

    expect(BranchAccessPolicy.canAccessBranch(owner, 'branch-b'), isTrue);
    expect(BranchAccessPolicy.canManageManagers(owner), isTrue);
    expect(BranchAccessPolicy.canCreateOrDeactivateBranch(owner), isTrue);
  });

  test('active manager with allBranches can access future branches', () {
    final manager = membership(allBranches: true);

    expect(BranchAccessPolicy.canAccessBranch(manager, 'branch-b'), isTrue);
  });

  test('active manager is restricted to assigned branches', () {
    final manager = membership();

    expect(BranchAccessPolicy.canAccessBranch(manager, 'branch-a'), isTrue);
    expect(BranchAccessPolicy.canAccessBranch(manager, 'branch-b'), isFalse);
    expect(BranchAccessPolicy.canManageManagers(manager), isFalse);
    expect(BranchAccessPolicy.canCreateOrDeactivateBranch(manager), isFalse);
  });

  for (final status in [MembershipStatus.suspended, MembershipStatus.removed]) {
    test('$status cannot access branches or manage structure', () {
      final owner = membership(role: MerchantRole.owner, status: status);
      final manager = membership(status: status, allBranches: true);

      expect(BranchAccessPolicy.canAccessBranch(owner, 'branch-a'), isFalse);
      expect(BranchAccessPolicy.canAccessBranch(manager, 'branch-a'), isFalse);
      expect(BranchAccessPolicy.canManageManagers(owner), isFalse);
      expect(BranchAccessPolicy.canCreateOrDeactivateBranch(owner), isFalse);
    });
  }
}
