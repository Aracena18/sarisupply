import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import 'package:sarisupply_pos/features/device_setup/presentation/device_setup_screen.dart';
import 'package:sarisupply_pos/features/owner_onboarding/presentation/merchant_application_screen.dart';

class _Applications extends Fake implements MerchantApplicationRepository {
  bool failSubmitOnce = false;
  final draftIds = <String?>[];
  int saved = 0;
  String? submitted;
  @override
  Future<String> saveDraft(
      {String? applicationId,
      required Map<String, Object?> businessProfile,
      required Map<String, Object?> firstBranchDraft}) async {
    saved++;
    draftIds.add(applicationId);
    expect(businessProfile['name'], 'Sari Store');
    expect(firstBranchDraft['code'], 'MAIN');
    return 'application-1';
  }

  @override
  Future<void> submit(String applicationId) async {
    if (failSubmitOnce) {
      failSubmitOnce = false;
      throw StateError('private-token');
    }
    submitted = applicationId;
  }
}

class _Memberships extends Fake implements MembershipRepository {
  @override
  Future<List<Branch>> listAccessibleBranches(
          MerchantMembership membership) async =>
      [
        Branch(
            id: 'branch-1',
            merchantId: 'merchant-1',
            name: 'Main',
            code: 'MAIN',
            address: 'Davao',
            contactDetails: const {},
            operatingHours: const {},
            status: BranchStatus.active,
            createdAt: DateTime.utc(2026, 9, 27),
            createdBy: 'owner-1',
            updatedAt: DateTime.utc(2026, 9, 27)),
      ];
}

class _CommittedApplications extends _Applications {
  int commits = 0;
  @override
  Future<MerchantApplication?> getApplication(String id) async =>
      MerchantApplication(
          id: id,
          applicantUid: 'owner',
          status: MerchantApplicationStatus.pendingReview,
          businessProfile: const {'name': 'Sari Store'},
          firstBranchDraft: const {
            'name': 'Main',
            'code': 'MAIN',
            'address': 'Davao'
          },
          submittedAt: DateTime.utc(2026),
          reviewedAt: null,
          reviewedBy: null,
          reviewNotes: null,
          approvedMerchantId: null);
  @override
  Future<void> submit(String id) async {
    commits++;
    throw StateError('Response lost after commit');
  }
}

class _Devices extends Fake implements DeviceRepository {
  bool failOnce = false;
  final operations = <String>[];
  String? branchId;
  @override
  Future<DeviceActivation> activate(
      {required String merchantId,
      required String branchId,
      required String displayName,
      required String platform,
      required String appVersion,
      required String operationId,
      bool keepHumanSignedIn = false}) async {
    this.branchId = branchId;
    operations.add(operationId);
    if (failOnce) {
      failOnce = false;
      throw StateError('uncertain-response');
    }
    return DeviceActivation(
        deviceId: 'device-1', merchantId: merchantId, branchId: branchId);
  }
}

void main() {
  testWidgets('server-committed submission advances after its response is lost',
      (tester) async {
    final applications = _CommittedApplications();
    var advanced = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MerchantApplicationScreen(
      applications: applications,
      onSubmitted: () => advanced++,
    )))));
    for (final entry in {
      'Business name': 'Sari Store',
      'First branch name': 'Main',
      'Branch code': 'main',
      'Branch address': 'Davao'
    }.entries) {
      await tester.enterText(
          find.widgetWithText(TextFormField, entry.key), entry.value);
    }
    await tester.tap(find.text('Submit application'));
    await tester.pumpAndSettle();
    expect(advanced, 1);
    expect(applications.commits, 1);
  });
  testWidgets('submit retry keeps saved draft and hides exception details',
      (tester) async {
    final applications = _Applications()..failSubmitOnce = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MerchantApplicationScreen(
      applications: applications,
      onSubmitted: () {},
    )))));
    for (final entry in {
      'Business name': 'Sari Store',
      'First branch name': 'Main',
      'Branch code': 'main',
      'Branch address': 'Davao'
    }.entries) {
      await tester.enterText(
          find.widgetWithText(TextFormField, entry.key), entry.value);
    }
    await tester.tap(find.text('Submit application'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private-token'), findsNothing);
    await tester.tap(find.text('Submit application'));
    await tester.pumpAndSettle();
    expect(applications.draftIds, [null, 'application-1']);
  });
  testWidgets('business and first branch are submitted for review',
      (tester) async {
    final applications = _Applications();
    var submitted = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MerchantApplicationScreen(
                    applications: applications,
                    onSubmitted: () => submitted++)))));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name'), 'Sari Store');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'First branch name'), 'Main');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Branch code'), 'main');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Branch address'), 'Davao');
    await tester.tap(find.text('Submit application'));
    await tester.pumpAndSettle();
    expect(applications.saved, 1);
    expect(applications.submitted, 'application-1');
    expect(submitted, 1);
  });

  testWidgets('device activation uses an authorized branch', (tester) async {
    final devices = _Devices()..failOnce = true;
    var activated = 0;
    final membership = MerchantMembership(
        userId: 'owner-1',
        merchantId: 'merchant-1',
        role: MerchantRole.owner,
        status: MembershipStatus.active,
        allBranches: true,
        branchIds: const [],
        createdAt: DateTime.utc(2026, 9, 27),
        createdBy: 'admin-1',
        updatedAt: DateTime.utc(2026, 9, 27));
    await tester.pumpWidget(MaterialApp(
        home: DeviceSetupScreen(
            memberships: [membership],
            membershipRepository: _Memberships(),
            devices: devices,
            onActivated: () => activated++,
            onSignOut: () {})));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activate device'));
    await tester.pumpAndSettle();
    expect(find.textContaining('uncertain-response'), findsNothing);
    await tester.tap(find.text('Activate device'));
    await tester.pumpAndSettle();
    expect(devices.operations.length, 2);
    expect(devices.operations[0], devices.operations[1]);
    expect(devices.branchId, 'branch-1');
    expect(activated, 1);
  });
}
