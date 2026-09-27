import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 27);

  test('membership preserves branch scope and status in its map', () {
    final membership = MerchantMembership(
      userId: 'user-1',
      merchantId: 'merchant-1',
      role: MerchantRole.manager,
      status: MembershipStatus.suspended,
      allBranches: false,
      branchIds: const ['branch-a'],
      createdAt: createdAt,
      createdBy: 'owner-1',
      updatedAt: createdAt,
    );

    final map = membership.toMap();
    expect(map['role'], 'manager');
    expect(map['status'], 'suspended');
    expect(map['allBranches'], false);
    expect(map['branchIds'], ['branch-a']);
    expect(MerchantMembership.fromMap(map).branchIds, ['branch-a']);
  });

  test('application uses pending_review wire value and keeps review context',
      () {
    final application = MerchantApplication(
      id: 'application-1',
      applicantUid: 'user-1',
      status: MerchantApplicationStatus.pendingReview,
      businessProfile: const {'name': 'Sari Store'},
      firstBranchDraft: const {'name': 'Main'},
      submittedAt: createdAt,
      reviewedAt: null,
      reviewedBy: null,
      reviewNotes: null,
      approvedMerchantId: null,
    );

    expect(application.toMap()['status'], 'pending_review');
    expect(MerchantApplication.fromMap(application.toMap()).status,
        MerchantApplicationStatus.pendingReview);
    expect(
        () => MerchantApplication.fromMap({
              ...application.toMap(),
              'status': 'unknown',
            }),
        throwsArgumentError);
  });

  test('rejected applications can be represented as resubmitted', () {
    expect(
      MerchantApplicationStatus.fromWireValue('resubmitted'),
      MerchantApplicationStatus.resubmitted,
    );
  });

  test('branch status and details survive serialization', () {
    final branch = Branch(
      id: 'branch-a',
      merchantId: 'merchant-1',
      name: 'Main',
      code: 'MAIN',
      address: 'Manila',
      contactDetails: const {'phone': '123'},
      operatingHours: const {'monday': '08:00-18:00'},
      status: BranchStatus.inactive,
      createdAt: createdAt,
      createdBy: 'owner-1',
      updatedAt: createdAt,
    );

    expect(branch.toMap()['status'], 'inactive');
    expect(Branch.fromMap(branch.toMap()).contactDetails['phone'], '123');
  });

  test('cashier profile excludes PIN material and keeps assignments', () {
    final cashier = Cashier(
      id: 'cashier-1',
      merchantId: 'merchant-1',
      displayName: 'Ana',
      employeeCode: 'A01',
      assignedBranchIds: const ['branch-a'],
      status: CashierStatus.active,
      mustChangePin: true,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final map = cashier.toMap();
    expect(map.keys, isNot(contains('pin')));
    expect(map['mustChangePin'], true);
    expect(Cashier.fromMap(map).assignedBranchIds, ['branch-a']);
  });

  test('revoked device status survives serialization', () {
    final device = PosDevice(
      id: 'device-1',
      merchantId: 'merchant-1',
      branchId: 'branch-a',
      displayName: 'Front counter',
      status: PosDeviceStatus.revoked,
      activatedAt: createdAt,
      activatedBy: 'owner-1',
      revokedAt: createdAt,
    );

    expect(device.toMap()['status'], 'revoked');
    expect(PosDevice.fromMap(device.toMap()).revokedAt, createdAt);
  });
}
