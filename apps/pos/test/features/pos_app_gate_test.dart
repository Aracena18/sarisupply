import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';

import 'package:sarisupply_pos/app/pos_app_gate.dart';
import 'package:sarisupply_pos/features/checkout/checkout_screen.dart';

class _Workflow extends Fake implements PosWorkflow {
  _Workflow(this.state);
  final PosGateState state;
  @override
  void lockCashier() {}
  @override
  CheckoutGateway get checkoutGateway => _CheckoutGateway();
  @override
  Future<IssuedCashierGrant?> readCheckoutGrant(
          String deviceId, String grantId) async =>
      null;
  @override
  Future<CheckoutAuthorization> authorizeCheckout(
          CashierSession session) async =>
      CheckoutAuthorization(
          scope: CheckoutScope(
              merchantId: 'store',
              branchId: 'branch-1',
              deviceId: session.deviceId,
              cashierId: session.cashierId,
              grantId: 'g',
              credentialVersion: 1),
          occurredAt: DateTime.utc(2026),
          merchantName: 'Store',
          branchName: 'Main');
  int invalidatedCheckoutSessions = 0;
  @override
  Future<void> invalidateCheckoutAuthorization(CashierSession session) async {
    invalidatedCheckoutSessions++;
  }

  int loadCount = 0;
  @override
  InventoryGateway get deviceInventory => _InventoryGateway();
  @override
  Future<List<CashierCredentialProjection>> listCashiers() async => [];
  int clearedSessions = 0;
  int humanSignIns = 0;
  int humanSignOuts = 0;
  @override
  Future<void> signIn() async {
    humanSignIns++;
  }

  @override
  Future<void> signOutHuman() async {
    humanSignOuts++;
  }

  @override
  ManagementRepository get management => _Management();
  @override
  CashierRepository get cashiers => _Cashiers();

  @override
  Future<PosGateSnapshot> load() async => PosGateSnapshot(
      state: state == PosGateState.cashierActive && loadCount++ > 0
          ? PosGateState.deviceReadyCashierLocked
          : state,
      session: CashierSession(
          cashierId: 'cashier',
          deviceId: 'device-1',
          startedAt: DateTime.utc(2026)),
      merchantId: 'store',
      branchId: 'branch-1',
      deviceId: [
        PosGateState.deviceReadyCashierLocked,
        PosGateState.cashierActive
      ].contains(state)
          ? 'device-1'
          : null);
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
  Future<List<MerchantMembership>> listMyMemberships() async => [
        MerchantMembership(
            userId: 'owner',
            merchantId: 'store',
            role: MerchantRole.owner,
            status: MembershipStatus.active,
            allBranches: true,
            branchIds: const [],
            createdAt: DateTime.utc(2026),
            createdBy: 'admin',
            updatedAt: DateTime.utc(2026))
      ];
  @override
  Future<List<ManagerInvitation>> listMyInvitations() async => [];
}

class _Devices extends Fake implements DeviceRepository {}

class _Cashiers extends Fake implements CashierRepository {}

class _Management extends Fake implements ManagementRepository {
  @override
  Future<ManagementPage> list(String merchantId, ManagementKind kind,
          {String? cursor}) async =>
      ManagementPage(records: []);
}

class _CheckoutGateway extends Fake implements CheckoutGateway {}

class _InventoryGateway extends Fake implements InventoryGateway {}

class _DelayedInventoryWorkflow extends _Workflow {
  _DelayedInventoryWorkflow() : super(PosGateState.cashierActive);
  final verification = Completer<PosGateSnapshot>();
  int loads = 0;
  int inventoryAccesses = 0;
  @override
  Future<PosGateSnapshot> load() async {
    if (++loads > 1) return verification.future;
    return const PosGateSnapshot(
        state: PosGateState.cashierActive,
        deviceId: 'device-1',
        merchantId: 'store',
        branchId: 'branch-1');
  }

  @override
  InventoryGateway get deviceInventory {
    inventoryAccesses++;
    return _InventoryGateway();
  }
}

class _SuccessfulWorkflow extends _Workflow {
  _SuccessfulWorkflow() : super(PosGateState.deviceReadyCashierLocked);
  @override
  Future<CashierLoginResult> loginCashier(String cashierId, String pin) async =>
      CashierLoginResult(CashierLoginStatus.signedIn,
          session: CashierSession(
              cashierId: cashierId,
              deviceId: 'device-1',
              startedAt: DateTime.utc(2026)));
}

class _GuardedWorkflow extends _Workflow {
  _GuardedWorkflow() : super(PosGateState.signedOut);
  final signingIn = Completer<void>();
  @override
  Future<void> signIn() {
    humanSignIns++;
    return signingIn.future;
  }
}

class _LoadRecoveryWorkflow extends _Workflow {
  _LoadRecoveryWorkflow() : super(PosGateState.signedOut);
  int attempts = 0;
  @override
  Future<PosGateSnapshot> load() async {
    if (attempts++ == 0) throw StateError('private detail');
    return const PosGateSnapshot(state: PosGateState.signedOut);
  }
}

class _MissingContextWorkflow extends _Workflow {
  _MissingContextWorkflow() : super(PosGateState.deviceReadyCashierLocked);
  int attempts = 0;
  @override
  Future<PosGateSnapshot> load() async {
    if (attempts++ == 0) {
      return const PosGateSnapshot(
          state: PosGateState.cashierActive, deviceId: 'device-1');
    }
    return super.load();
  }
}

void main() {
  testWidgets(
      'missing device context retries the gate instead of repeating a dead end',
      (tester) async {
    final workflow = _MissingContextWorkflow();
    await tester.pumpWidget(MaterialApp(home: PosAppGate(workflow: workflow)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(workflow.attempts, 2);
    expect(find.text('Cashier sign in'), findsOneWidget);
  });

  testWidgets('POS sign-in is guarded while pending', (tester) async {
    final workflow = _GuardedWorkflow();
    await tester.pumpWidget(MaterialApp(home: PosAppGate(workflow: workflow)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    await tester.tap(find.text('Signing in…'));
    await tester.pump();
    expect(workflow.humanSignIns, 1);
    workflow.signingIn.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('POS load error offers safe retry', (tester) async {
    final workflow = _LoadRecoveryWorkflow();
    await tester.pumpWidget(MaterialApp(home: PosAppGate(workflow: workflow)));
    await tester.pumpAndSettle();
    expect(find.textContaining('private detail'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(workflow.attempts, 2);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('successful sign-in opens checkout directly and Lock disposes it',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: PosAppGate(workflow: _SuccessfulWorkflow())));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cashier ID'), 'ana');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '483920');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Ready to work'), findsNothing);
    await tester.tap(find.byTooltip('Lock'));
    await tester.pumpAndSettle();
    expect(find.text('Cashier sign in'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);
  });

  testWidgets(
      'observed checkout revocation dismisses every child route before sign-in',
      (tester) async {
    final workflow = _SuccessfulWorkflow();
    await tester.pumpWidget(MaterialApp(home: PosAppGate(workflow: workflow)));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cashier ID'), 'ana');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '483920');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    final checkout = tester.widget<CheckoutScreen>(find.byType(CheckoutScreen));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Saved receipt route')))));
    await tester.pumpAndSettle();
    unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Scanner route')))));
    await tester.pumpAndSettle();
    await checkout.onAccessDenied!();
    await tester.pumpAndSettle();
    expect(workflow.invalidatedCheckoutSessions, 1);
    expect(find.text('Scanner route'), findsNothing);
    expect(find.text('Saved receipt route'), findsNothing);
    expect(find.text('Cashier sign in'), findsOneWidget);
  });
  testWidgets('checkout never opens an old branch after device scope changes',
      (tester) async {
    final workflow = _DelayedInventoryWorkflow();
    await tester.pumpWidget(MaterialApp(home: PosAppGate(workflow: workflow)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Checkout'), findsOneWidget);
    workflow.verification.complete(const PosGateSnapshot(
        state: PosGateState.deviceReadyCashierLocked,
        deviceId: 'device-1',
        merchantId: 'store',
        branchId: 'branch-2'));
    await tester.pumpAndSettle();
    expect(workflow.inventoryAccesses, 0);
    expect(find.text('Cashier sign in'), findsOneWidget);
  });

  testWidgets('late workspace denial cannot replace an ended cashier session',
      (tester) async {
    final workflow = _DelayedInventoryWorkflow();
    await tester.pumpWidget(MaterialApp(home: PosAppGate(workflow: workflow)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Checkout'), findsOneWidget);
    await tester.tap(find.byTooltip('Lock'));
    await tester.pumpAndSettle();
    workflow.verification
        .complete(const PosGateSnapshot(state: PosGateState.deviceRevoked));
    await tester.pumpAndSettle();
    expect(workflow.loads, 2);
    expect(workflow.inventoryAccesses, 0);
    expect(find.text('Cashier sign in'), findsOneWidget);
  });
  testWidgets('management signs out its human session and keeps device session',
      (tester) async {
    final workflow = _Workflow(PosGateState.deviceReadyCashierLocked);
    await tester.pumpWidget(MaterialApp(home: PosAppGate(workflow: workflow)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage store'));
    await tester.pumpAndSettle();
    expect(find.text('Add cashier'), findsOneWidget);
    expect(workflow.humanSignIns, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(workflow.humanSignOuts, 1);
    expect(workflow.clearedSessions, 0);
    expect(find.text('Cashier sign in'), findsOneWidget);
  });
  final cases = <PosGateState, String>{
    PosGateState.signedOut: 'Sign in with Google',
    PosGateState.noMerchant: 'Set up your store',
    PosGateState.pendingMerchant: 'Application pending review',
    PosGateState.approvedNeedsDeviceActivation: 'Activate this POS',
    PosGateState.deviceReadyCashierLocked: 'Cashier sign in',
    PosGateState.deviceRevoked: 'Device access revoked',
    PosGateState.offlineCredentialsExpired: 'Reconnect to continue',
    PosGateState.cashierActive: 'Checkout',
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
    expect(find.text('Checkout'), findsOneWidget);
  });
}
