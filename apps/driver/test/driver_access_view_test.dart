import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_driver/app/driver_access_view.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

AuthorizationWorkspace workspace(CompanyRole role) => AuthorizationWorkspace(
      companyId: 'company',
      displayName: 'SariSupply',
      role: role,
      scope: CompanyScope.fromMap({
        'kind': 'warehouses',
        'warehouseIds': ['warehouse']
      }, role),
      membershipRevision: 1,
      roleGrantRevision: 1,
    );

void main() {
  testWidgets('rider workspace opens while company operations stay secondary',
      (tester) async {
    AuthorizationWorkspace? selected;
    final rider = workspace(CompanyRole.rider);
    await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light,
        home: DriverAccessView(
          workspaces: [workspace(CompanyRole.warehouseOperations), rider],
          invitations: const [],
          legacyWorkspaces: const [],
          onWorkspace: (value) => selected = value,
          onLegacyWorkspace: (_) {},
          onAccept: (_) {},
          onRefresh: () {},
          onSignOut: () {},
        )));
    expect(find.text('Rider · 1 assigned warehouse'), findsOneWidget);
    expect(find.textContaining('open Admin'), findsNothing);
    await tester.tap(find.text('Rider · 1 assigned warehouse'));
    expect(selected, same(rider));
    await tester.tap(find.text('Other company roles'));
    await tester.pumpAndSettle();
    expect(find.textContaining('open Admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'invitations fit a small phone at large text and keep acceptance reachable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CompanyInvitation? accepted;
    final invitation = CompanyInvitation(
        id: 'invite',
        companyId: 'company',
        companyName: 'SariSupply',
        role: CompanyRole.rider,
        warehouseIds: ['warehouse'],
        status: 'pending',
        expiresAt: DateTime(2026, 10, 10));
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!),
      home: DriverAccessView(
          workspaces: const [],
          invitations: [invitation],
          legacyWorkspaces: const [],
          onWorkspace: (_) {},
          onLegacyWorkspace: (_) {},
          onAccept: (value) => accepted = value,
          onRefresh: () {},
          onSignOut: () {}),
    ));
    await tester.scrollUntilVisible(find.text('Accept invitation'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept invitation'));
    expect(accepted, same(invitation));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading disables workspace selection and refresh',
      (tester) async {
    var selections = 0;
    await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light,
        home: DriverAccessView(
          workspaces: [workspace(CompanyRole.rider)],
          invitations: const [],
          legacyWorkspaces: const [],
          loading: true,
          onWorkspace: (_) => selections++,
          onLegacyWorkspace: (_) {},
          onAccept: (_) {},
          onRefresh: () {},
          onSignOut: () {},
        )));
    await tester.tap(find.text('Rider · 1 assigned warehouse'));
    expect(selections, 0);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    expect(find.text('Loading your assignments…'), findsOneWidget);
  });
}
