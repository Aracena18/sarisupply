import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_company/sarisupply_company.dart';
import 'package:sarisupply_admin/features/company/presentation/company_workspace_screen.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

const workspaceData = <String, Object?>{
  'kind': 'company',
  'companyId': 'company-1',
  'displayName': 'Company',
  'role': 'companyOwner',
  'scope': {'kind': 'company'},
  'membershipRevision': 1,
  'roleGrantRevision': 1,
};

class CompanyGateway implements MerchantCallableGateway {
  CompanyGateway({this.members = const []});
  final List<Map<String, Object?>> members;

  @override
  Future<Map<String, Object?>> call(
      String name, Map<String, Object?> payload) async {
    switch (name) {
      case 'getCompanyWorkspace':
        return {
          ...workspaceData,
          'authorizationVersion': 1,
          'source': 'server',
          'verifiedAt': '2026-10-06T00:00:00Z',
        };
      case 'listCompanyWarehouses':
        return {
          'authorizationVersion': 1,
          'hasMore': false,
          'warehouses': [
            {
              'warehouseId': 'warehouse-1',
              'name': 'Warehouse',
              'code': 'WH',
              'address': ''
            }
          ],
        };
      case 'listCompanyInvitations':
        return {'authorizationVersion': 1, 'hasMore': false, 'invitations': []};
      case 'listCompanyStaff':
        return {
          'authorizationVersion': 1,
          'hasMore': false,
          'members': members
        };
      default:
        throw StateError('Unexpected command: $name');
    }
  }
}

void main() {
  for (final action in [
    'Invite staff',
    'Add warehouse',
    'Payment instructions'
  ]) {
    testWidgets('$action closes without disposing a mounted text controller',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CompanyWorkspaceScreen(
          workspace: AuthorizationWorkspace.fromMap(workspaceData),
          authorization:
              AuthorizationWorkspaceFunctions(gateway: CompanyGateway()),
          onSignOut: () async {},
        ),
      ));
      await tester.pumpAndSettle();
      if (action == 'Invite staff') {
        await tester.ensureVisible(find.text('Team'));
        await tester.tap(find.text('Team'));
        await tester.pumpAndSettle();
      } else if (action == 'Payment instructions') {
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      await tester.enterText(
          find
              .descendant(
                  of: find.byType(SariSupplyFormSurface),
                  matching: find.byType(TextField))
              .first,
          'draft');
      await tester.tap(find.text('Cancel'));
      // Exercise rebuilding during the reverse transition, not only after it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (action == 'Invite staff') {
        await tester.ensureVisible(find.text('Team'));
        await tester.tap(find.text('Team'));
        await tester.pumpAndSettle();
      } else if (action == 'Payment instructions') {
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextField>(find
                  .descendant(
                      of: find.byType(SariSupplyFormSurface),
                      matching: find.byType(TextField))
                  .first)
              .controller!
              .text,
          isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('owner roster fits 320px at 200% and searches named warehouses',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: CompanyWorkspaceScreen(
        workspace: AuthorizationWorkspace.fromMap(workspaceData),
        authorization: AuthorizationWorkspaceFunctions(
            gateway: CompanyGateway(members: [
          {
            'memberId': 'staff-1',
            'email': 'long.warehouse.member@example.com',
            'role': 'warehouseOperations',
            'scope': {
              'kind': 'warehouses',
              'warehouseIds': ['warehouse-1']
            },
          },
        ])),
        onSignOut: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Team'));
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('long.warehouse.member@example.com'),
      200,
      scrollable: find
          .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Warehouse Operations\nWarehouse'), findsOneWidget);
    final search = find.byType(TextField);
    await tester.scrollUntilVisible(search, -200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(search);
    await tester.enterText(search, 'unmatched');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('No matching members'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('No matching members'), findsOneWidget);
    await tester.scrollUntilVisible(search, -200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    await tester.enterText(search, 'Warehouse');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('long.warehouse.member@example.com'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('long.warehouse.member@example.com'), findsOneWidget);
    await tester.scrollUntilVisible(search, -200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    expect(tester.widget<TextField>(search).controller!.text, 'Warehouse');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Company retains all main destinations and returns the chosen page',
      (tester) async {
    final selected = ValueNotifier<int>(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      home: Builder(
          builder: (context) => ValueListenableBuilder<int>(
                valueListenable: selected,
                builder: (context, index, _) => Scaffold(
                  body: Text('Operations $index'),
                  bottomNavigationBar: CompanyNavigationBar(
                    selectedIndex: index,
                    onDestinationSelected: (destination) async {
                      if (destination != 3) {
                        selected.value = destination;
                        return;
                      }
                      final result = await Navigator.of(context)
                          .push<int>(MaterialPageRoute<int>(
                        builder: (pageContext) => CompanyWorkspaceScreen(
                          workspace:
                              AuthorizationWorkspace.fromMap(workspaceData),
                          authorization: AuthorizationWorkspaceFunctions(
                              gateway: CompanyGateway()),
                          onSignOut: () async {},
                          onNavigate: (next) =>
                              Navigator.of(pageContext).pop(next),
                        ),
                      ));
                      if (result != null) selected.value = result;
                    },
                  ),
                ),
              )),
    ));
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Company')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
    for (final label in ['Orders', 'Stock', 'Deliveries', 'Company']) {
      expect(
          find
              .descendant(
                  of: find.byType(NavigationBar), matching: find.text(label))
              .hitTestable(),
          findsOneWidget);
    }
    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();
    expect(find.text('Operations 1'), findsOneWidget);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    expect(tester.takeException(), isNull);
  });
}
