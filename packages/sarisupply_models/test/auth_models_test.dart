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

  test('application copies and freezes nested map, list, and set input', () {
    final tags = <String>{'retail'};
    final contacts = <Object?>[
      <String, String>{'phone': '123'},
      tags
    ];
    final profile = <String, Object?>{'contacts': contacts};
    final hours = <Object?>[
      <String, String>{'open': '08:00'}
    ];
    final application = MerchantApplication(
        id: 'application-1',
        applicantUid: 'user-1',
        status: MerchantApplicationStatus.draft,
        businessProfile: profile,
        firstBranchDraft: {'hours': hours},
        submittedAt: null,
        reviewedAt: null,
        reviewedBy: null,
        reviewNotes: null,
        approvedMerchantId: null);
    (contacts[0] as Map<String, String>)['phone'] = '999';
    tags.add('wholesale');
    contacts.add('new');
    (hours[0] as Map<String, String>)['open'] = '10:00';
    final stored = application.businessProfile['contacts'] as List;
    expect((stored[0] as Map)['phone'], '123');
    expect(stored[1], {'retail'});
    expect(stored, hasLength(2));
    expect(((application.firstBranchDraft['hours'] as List)[0] as Map)['open'],
        '08:00');
    expect(() => (stored[0] as Map)['phone'] = '456', throwsUnsupportedError);
    expect(() => (stored[1] as Set).add('new'), throwsUnsupportedError);
  });

  test('branch copies and freezes nested collection input', () {
    final phones = <Object?>[
      <String, String>{'number': '123'}
    ];
    final hours = <String, Object?>{
      'monday': <Object?>['08:00']
    };
    final branch = Branch(
        id: 'branch-a',
        merchantId: 'merchant-1',
        name: 'Main',
        code: 'MAIN',
        address: 'Manila',
        contactDetails: {'phones': phones},
        operatingHours: hours,
        status: BranchStatus.active,
        createdAt: createdAt,
        createdBy: 'owner-1',
        updatedAt: createdAt);
    (phones[0] as Map<String, String>)['number'] = '999';
    (hours['monday'] as List).add('20:00');
    expect(
        ((branch.contactDetails['phones'] as List)[0] as Map)['number'], '123');
    expect(branch.operatingHours['monday'], ['08:00']);
    expect(() => (branch.operatingHours['monday'] as List).add('22:00'),
        throwsUnsupportedError);
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
