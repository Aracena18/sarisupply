import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

Future<void> loadUiFonts() async {
  final loader = FontLoader('packages/sarisupply_design_system/NunitoSans');
  for (final w in [400, 600, 700]) {
    loader.addFont(rootBundle.load(
        'packages/sarisupply_design_system/assets/fonts/NunitoSans-$w.ttf'));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Widget fixtureApp(Widget screen, {double scale = 1, double keyboard = 0}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SariSupplyTheme.light(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: child!),
      home: screen,
    );
void fixtureSize(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

MerchantMembership fixtureMember([MerchantRole role = MerchantRole.owner]) =>
    MerchantMembership(
        userId: 'owner',
        merchantId: 'store',
        merchantName: 'Aling Nena’s Sari-Sari Store',
        role: role,
        status: MembershipStatus.active,
        allBranches: true,
        branchIds: const [],
        createdAt: DateTime.utc(2026),
        createdBy: 'admin',
        updatedAt: DateTime.utc(2026));
Branch fixtureBranch(String id) => Branch(
    id: id,
    merchantId: 'store',
    name: 'Main branch $id',
    code: id.toUpperCase(),
    address: 'Davao City',
    contactDetails: const {},
    operatingHours: const {},
    status: BranchStatus.active,
    createdAt: DateTime.utc(2026),
    createdBy: 'owner',
    updatedAt: DateTime.utc(2026));
MerchantApplication fixtureApplication(MerchantApplicationStatus status) =>
    MerchantApplication(
        id: 'application',
        applicantUid: 'owner',
        status: status,
        businessProfile: const {'name': 'Aling Nena’s Sari-Sari Store'},
        firstBranchDraft: const {
          'name': 'Main branch',
          'code': 'MAIN',
          'address': 'Barangay Matina, Davao City'
        },
        submittedAt: DateTime.utc(2026, 10, 4),
        reviewedAt: null,
        reviewedBy: null,
        reviewNotes: status == MerchantApplicationStatus.rejected
            ? 'Please confirm your branch address.'
            : null,
        approvedMerchantId: null);
CatalogProduct fixtureProduct({int units = 2, String id = 'rice'}) =>
    CatalogProduct(
        id: id,
        sku: id.toUpperCase(),
        name: id == 'rice' ? 'Sinandomeng rice' : 'Instant coffee',
        baseUnit: 'bag',
        revision: 1,
        active: true,
        units: [
          CatalogUnit(
              name: 'bag',
              factor: 1,
              priceCentavos: 5500,
              barcode: id == 'rice' ? '000123' : '100123'),
          for (var i = 1; i < units; i++)
            CatalogUnit(
                name: 'bundle $i',
                factor: i + 1,
                priceCentavos: 5500 * (i + 1),
                barcode: '${id == 'rice' ? '000' : '100'}${123 + i}')
        ]);

class FixtureMemberships extends Fake implements MembershipRepository {
  List<Branch> branches = [fixtureBranch('main')];
  List<ManagerInvitation> invitations = [];
  bool failInvitations = false;
  bool failBranches = false;
  Completer<void>? acceptGate;
  int accepted = 0;
  @override
  Future<List<Branch>> listAccessibleBranches(
          MerchantMembership member) async =>
      failBranches ? throw StateError('private detail') : branches;
  @override
  Future<List<ManagerInvitation>> listMyInvitations() async {
    if (failInvitations) {
      throw StateError('private detail');
    }
    return invitations;
  }

  @override
  Future<void> acceptManagerInvitation(
      String merchantId, String inviteId) async {
    accepted++;
    await acceptGate?.future;
  }
}

class FixtureApplications extends Fake
    implements MerchantApplicationRepository {}

class FixtureDevices extends Fake implements DeviceRepository {}

class FixtureCashiers extends Fake implements CashierRepository {}

class FixtureManagement extends Fake implements ManagementRepository {
  ManagementKind? lastKind;
  bool fail = false;
  List<ManagementRecord> records = [
    ManagementRecord(
        id: 'ana',
        name: 'Ana Santos',
        code: 'EMP01',
        status: 'active',
        branchIds: ['main'],
        allBranches: false)
  ];
  @override
  Future<ManagementPage> list(String merchantId, ManagementKind kind,
      {String? cursor}) async {
    lastKind = kind;
    if (fail) {
      throw StateError('private detail');
    }
    return ManagementPage(records: records);
  }
}

class FixtureGateway extends Fake implements InventoryGateway {}
