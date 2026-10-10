import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/management/presentation/management_screen.dart';
import 'package:sarisupply_pos/features/management/presentation/management_form_dialog.dart';

class _Pages extends Fake implements ManagementRepository {
  final cursors = <String?>[];
  final kinds = <ManagementKind>[];
  bool denied = false;
  @override
  Future<ManagementPage> list(String merchant, ManagementKind kind,
      {String? cursor}) async {
    cursors.add(cursor);
    kinds.add(kind);
    if (denied) {
      throw FirebaseException(plugin: 'fixture', code: 'permission-denied');
    }
    return ManagementPage(
        records: cursor == null
            ? []
            : [
                ManagementRecord(
                    id: 'ana',
                    name: 'Ana',
                    code: 'EMP1',
                    status: 'active',
                    branchIds: ['main'],
                    allBranches: false)
              ],
        nextCursor: cursor == null ? 'first-page' : null);
  }
}

class _Memberships extends Fake implements MembershipRepository {}

class _Devices extends Fake implements DeviceRepository {}

class _Cashiers extends Fake implements CashierRepository {
  int resets = 0;
  @override
  Future<IssuedCashierPin> resetPin(String merchant, String id) async {
    resets++;
    return IssuedCashierPin(
        cashierId: id, temporaryPin: '483920', credentialVersion: 2);
  }
}

MerchantMembership _member(MerchantRole role, {String merchantId = 'store'}) =>
    MerchantMembership(
        userId: 'human',
        merchantId: merchantId,
        role: role,
        status: MembershipStatus.active,
        allBranches: role == MerchantRole.owner,
        branchIds: ['main'],
        createdAt: DateTime.utc(2026),
        createdBy: 'owner',
        updatedAt: DateTime.utc(2026));
void main() {
  testWidgets('revoked management access clears cached rows and disables work',
      (tester) async {
    final pages = _Pages();
    await tester.pumpWidget(MaterialApp(
        home: ManagementScreen(
            memberships: [_member(MerchantRole.manager)],
            management: pages,
            membershipRepository: _Memberships(),
            cashiers: _Cashiers(),
            devices: _Devices())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    pages.denied = true;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsNothing);
    final add = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add cashier'));
    expect(add.onPressed, isNull);
    final calls = pages.kinds.length;
    await tester.tap(find.text('Branches').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team').last);
    await tester.pumpAndSettle();
    expect(pages.kinds, hasLength(calls));
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('management search filters and clears loaded records',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: ManagementScreen(
            memberships: [_member(MerchantRole.manager)],
            management: _Pages(),
            membershipRepository: _Memberships(),
            cashiers: _Cashiers(),
            devices: _Devices())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsNothing);
    expect(find.text('No matching cashiers in the loaded records.'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.text('Branches').last);
    await tester.pumpAndSettle();
    expect(find.text('missing'), findsNothing);
  });

  testWidgets('changing stores retains the Branches and Devices page kind',
      (tester) async {
    final pages = _Pages();
    await tester.pumpWidget(MaterialApp(
        home: ManagementScreen(
            memberships: [
          _member(MerchantRole.owner),
          _member(MerchantRole.manager, merchantId: 'second'),
        ],
            management: pages,
            membershipRepository: _Memberships(),
            cashiers: _Cashiers(),
            devices: _Devices())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branches').last);
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('second');
    await tester.pumpAndSettle();
    expect(pages.kinds.last, ManagementKind.branches);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
    await tester.tap(find.text('Devices').last);
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('store');
    await tester.pumpAndSettle();
    expect(pages.kinds.last, ManagementKind.devices);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('access reassignment removes inactive assignments explicitly',
      (tester) async {
    List<String>? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ManagementFormDialog(
      action: ManagementAction.access,
      existing: ManagementRecord(
          id: 'manager',
          name: 'Ana',
          code: '',
          status: 'active',
          branchIds: ['retired'],
          allBranches: false),
      branches: [
        Branch(
            id: 'main',
            merchantId: 'store',
            name: 'Main',
            code: 'MAIN',
            address: 'Davao',
            contactDetails: const {},
            operatingHours: const {},
            status: BranchStatus.active,
            createdAt: DateTime.utc(2026),
            createdBy: 'owner',
            updatedAt: DateTime.utc(2026))
      ],
      onSubmit: (_, __, ids, ___) async {
        saved = ids;
        return null;
      },
    ))));
    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save access'));
    await tester.pumpAndSettle();
    expect(saved, ['main']);
  });
  for (final width in [390.0, 1024.0]) {
    testWidgets(
        'management handles empty filtered pages and scoped role at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pages = _Pages();
      await tester.pumpWidget(MaterialApp(
          home: ManagementScreen(
              memberships: [_member(MerchantRole.manager)],
              management: pages,
              membershipRepository: _Memberships(),
              cashiers: _Cashiers(),
              devices: _Devices())));
      await tester.pumpAndSettle();
      expect(find.text('Managers'), findsNothing);
      expect(find.text('Invitations'), findsNothing);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      expect(pages.cursors, [null, 'first-page']);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('PIN reset requires confirmation and disclosure is dismissible',
      (tester) async {
    final cashiers = _Cashiers();
    await tester.pumpWidget(MaterialApp(
        home: ManagementScreen(
            memberships: [_member(MerchantRole.owner)],
            management: _Pages(),
            membershipRepository: _Memberships(),
            cashiers: cashiers,
            devices: _Devices())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset PIN'));
    await tester.pumpAndSettle();
    expect(cashiers.resets, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cashiers.resets, 0);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset PIN'));
    await tester.pumpAndSettle();
    expect(cashiers.resets, 1);
    expect(find.text('483920'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('483920'), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset PIN'));
    await tester.pumpAndSettle();
    expect(find.text('483920'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('483920'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  testWidgets(
      'creation validates details, keeps retry ID and hides private errors',
      (tester) async {
    final ids = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ManagementFormDialog(
                action: ManagementAction.cashier,
                branches: [
                  Branch(
                      id: 'main',
                      merchantId: 'store',
                      name: 'Main',
                      code: 'MAIN',
                      address: 'Davao',
                      contactDetails: const {},
                      operatingHours: const {},
                      status: BranchStatus.active,
                      createdAt: DateTime.utc(2026),
                      createdBy: 'owner',
                      updatedAt: DateTime.utc(2026))
                ],
                onSubmit: (id, fields, branches, all) async {
                  ids.add(id);
                  expect(branches, ['main']);
                  if (ids.length == 1) throw StateError('private-token');
                  return null;
                }))));
    await tester.tap(find.widgetWithText(FilledButton, 'Add cashier'));
    await tester.pumpAndSettle();
    expect(ids, isEmpty);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Cashier name'), 'Ana');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Employee code'), 'EMP1');
    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add cashier'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private-token'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Add cashier'));
    await tester.pumpAndSettle();
    expect(ids.length, 2);
    expect(ids[0], ids[1]);
  });

  testWidgets('owner navigation exposes overview and visible team categories',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pages = _Pages();
    await tester.pumpWidget(MaterialApp(
        home: ManagementScreen(
            memberships: [_member(MerchantRole.owner)],
            management: pages,
            membershipRepository: _Memberships(),
            cashiers: _Cashiers(),
            devices: _Devices())));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Branches'), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<ManagementKind>), findsNothing);

    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.text('Cashiers'), findsOneWidget);
    expect(find.text('Managers'), findsOneWidget);
    expect(find.text('Invitations'), findsOneWidget);
    await tester.tap(find.text('Managers'));
    await tester.pumpAndSettle();
    expect(pages.kinds.last, ManagementKind.managers);

    await tester.tap(find.text('Branches'));
    await tester.pumpAndSettle();
    expect(pages.kinds.last, ManagementKind.branches);
    expect(tester.takeException(), isNull);
  });
}
