import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';

import 'package:sarisupply_pos/app/pos_app_gate.dart';

class _Workflow extends Fake implements PosWorkflow {
  _Workflow(this.state);
  final PosGateState state;
  int clearedSessions = 0;

  @override
  Future<PosGateSnapshot> load() async => PosGateSnapshot(
      state: state,
      deviceId:
          state == PosGateState.deviceReadyCashierLocked ? 'device-1' : null);
  @override
  MerchantApplicationRepository get applications => _Applications();
  @override
  MembershipRepository get memberships => _Memberships();
  @override
  DeviceRepository get devices => _Devices();
  @override
  Future<void> clearDeviceSession() async {
    clearedSessions++;
  }

  @override
  Future<CashierLoginResult> loginCashier(String cashierId, String pin) async =>
      const CashierLoginResult(CashierLoginStatus.requiresPinChange);

  @override
  Future<CashierLoginResult> changePin(
          String cashierId, String currentPin, String newPin) async =>
      CashierLoginResult(CashierLoginStatus.signedIn,
          session: CashierSession(
              cashierId: cashierId,
              deviceId: 'device-1',
              startedAt: DateTime.utc(2026, 9, 27)));
}

class _Applications extends Fake implements MerchantApplicationRepository {}

class _Memberships extends Fake implements MembershipRepository {
  @override
  Future<List<ManagerInvitation>> listMyInvitations() async => [];
}

class _Devices extends Fake implements DeviceRepository {}

void main() {
  final cases = <PosGateState, String>{
    PosGateState.signedOut: 'Sign in with Google',
    PosGateState.noMerchant: 'Set up your store',
    PosGateState.pendingMerchant: 'Application pending review',
    PosGateState.approvedNeedsDeviceActivation: 'Activate this POS',
    PosGateState.deviceReadyCashierLocked: 'Cashier sign in',
    PosGateState.deviceRevoked: 'Device access revoked',
    PosGateState.offlineCredentialsExpired: 'Reconnect to continue',
    PosGateState.cashierActive: 'Cashier active',
  };

  for (final entry in cases.entries) {
    testWidgets('shows ${entry.key} state', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: PosAppGate(workflow: _Workflow(entry.key))));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('revoked device can return to setup', (tester) async {
    final workflow = _Workflow(PosGateState.deviceRevoked);
    await tester.pumpWidget(MaterialApp(home: PosAppGate(workflow: workflow)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set up again'));
    await tester.pumpAndSettle();
    expect(workflow.clearedSessions, 1);
  });

  testWidgets('temporary PIN routes to change before cashier unlock',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PosAppGate(
            workflow: _Workflow(PosGateState.deviceReadyCashierLocked))));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Cashier ID'), 'cashier-1');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Change temporary PIN'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Temporary PIN'), '123456');
    await tester.enterText(find.widgetWithText(TextField, 'New PIN'), '654321');
    await tester.tap(find.text('Save new PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Cashier active'), findsOneWidget);
  });
}
