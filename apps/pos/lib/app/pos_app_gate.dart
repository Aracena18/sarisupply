import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import '../features/cashier_auth/domain/cashier_login_service.dart';
import '../features/cashier_auth/presentation/cashier_login_screen.dart';
import '../features/cashier_auth/presentation/change_temporary_pin_screen.dart';
import '../features/cashier_auth/presentation/offline_auth_blocked_screen.dart';
import '../features/device_setup/presentation/device_setup_screen.dart';
import '../features/owner_onboarding/presentation/owner_onboarding_gate.dart';
import '../features/management/presentation/management_screen.dart';
import '../features/catalog/catalog_branch_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/catalog/inventory_database.dart';

enum PosGateState {
  signedOut,
  noMerchant,
  pendingMerchant,
  approvedNeedsDeviceActivation,
  deviceReadyCashierLocked,
  cashierActive,
  deviceRevoked,
  offlineCredentialsExpired,
}

final class PosGateSnapshot {
  const PosGateSnapshot({
    required this.state,
    this.application,
    this.memberships = const [],
    this.deviceId,
    this.merchantId,
    this.branchId,
    this.session,
    this.recoveryMessage,
  });

  final PosGateState state;
  final MerchantApplication? application;
  final List<MerchantMembership> memberships;
  final String? deviceId;
  final String? merchantId;
  final String? branchId;
  final CashierSession? session;
  final String? recoveryMessage;
}

abstract interface class PosWorkflow {
  InventoryGateway get humanInventory;
  InventoryGateway get deviceInventory;
  CheckoutGateway get checkoutGateway;
  Future<IssuedCashierGrant?> readCheckoutGrant(
      String deviceId, String grantId);
  ManagementRepository get management;
  CashierRepository get cashiers;
  Future<List<CashierCredentialProjection>> listCashiers();
  MerchantApplicationRepository get applications;
  MembershipRepository get memberships;
  DeviceRepository get devices;
  Future<CheckoutAuthorization> authorizeCheckout(CashierSession session);
  void lockCashier();
  Future<void> invalidateCheckoutAuthorization(CashierSession session);
  Future<PosGateSnapshot> load();
  Future<void> signIn();
  Future<void> signOutHuman();
  Future<void> clearDeviceSession();
  Future<CashierLoginResult> loginCashier(String cashierId, String pin);
  Future<CashierLoginResult> changePin(
      String cashierId, String currentPin, String newPin);
}

class PosAppGate extends StatefulWidget {
  const PosAppGate({super.key, required this.workflow});
  final PosWorkflow workflow;

  @override
  State<PosAppGate> createState() => _PosAppGateState();
}

class _PosAppGateState extends State<PosAppGate> {
  PosGateSnapshot? _snapshot;
  String? _needsPinChangeId;
  String? _error;
  bool _loading = true;
  bool _actionPending = false;
  bool _inventoryReady = false;
  String? _workspaceError;
  int _sessionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (_snapshot?.session != null) {
      _dismissCheckoutRoutes();
      widget.workflow.lockCashier();
    }
    final generation = ++_sessionGeneration;
    setState(() {
      _inventoryReady = false;
      _workspaceError = null;
      _loading = true;
      _error = null;
    });
    try {
      final next = await widget.workflow.load();
      if (mounted && generation == _sessionGeneration) {
        setState(() {
          _snapshot = next;
          _needsPinChangeId = null;
          _loading = false;
        });
        if (next.state == PosGateState.cashierActive) _inventory();
      }
    } catch (error) {
      if (mounted && generation == _sessionGeneration) {
        setState(() {
          _error = operationErrorMessage(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _signIn() async {
    if (_actionPending) return;
    setState(() => _actionPending = true);
    try {
      await widget.workflow.signIn();
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _signOut() async {
    if (_actionPending) return;
    setState(() => _actionPending = true);
    try {
      await widget.workflow.signOutHuman();
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  void _onLoginResult(String cashierId, CashierLoginResult result) {
    final current = _snapshot;
    if (current == null) return;
    setState(() {
      _sessionGeneration++;
      switch (result.status) {
        case CashierLoginStatus.signedIn:
          _snapshot = PosGateSnapshot(
              state: PosGateState.cashierActive,
              deviceId: current.deviceId,
              merchantId: current.merchantId,
              branchId: current.branchId,
              session: result.session);
          _needsPinChangeId = null;
        case CashierLoginStatus.requiresPinChange:
          _needsPinChangeId = cashierId;
        case CashierLoginStatus.requiresOnlineRefresh ||
              CashierLoginStatus.requiresOnlineReenrollment:
          _snapshot = PosGateSnapshot(
            state: PosGateState.offlineCredentialsExpired,
            deviceId: current.deviceId,
            merchantId: current.merchantId,
            branchId: current.branchId,
          );
        case CashierLoginStatus.invalidPin || CashierLoginStatus.cooldown:
          break;
      }
    });
    if (result.status == CashierLoginStatus.signedIn) _inventory();
  }

  Future<void> _manage() async {
    final deviceSession = _snapshot?.deviceId != null;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (deviceSession) await widget.workflow.signIn();
      final memberships = await widget.workflow.memberships.listMyMemberships();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ManagementScreen(
                memberships: memberships,
                management: widget.workflow.management,
                membershipRepository: widget.workflow.memberships,
                cashiers: widget.workflow.cashiers,
                devices: widget.workflow.devices,
                onCatalog: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => CatalogBranchScreen(
                            memberships: memberships,
                            repository: widget.workflow.memberships,
                            gateway: widget.workflow.humanInventory))),
              )));
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (deviceSession) {
        try {
          await widget.workflow.signOutHuman();
        } catch (error) {
          if (mounted) setState(() => _error = operationErrorMessage(error));
        }
      }
      if (mounted) setState(() => _loading = false);
    }
    if (mounted && _error == null) await _reload();
  }

  void _dismissCheckoutRoutes() {
    final gateRoute = ModalRoute.of(context);
    if (gateRoute != null) {
      Navigator.of(context).popUntil((route) => identical(route, gateRoute));
    }
  }

  void _lock() {
    _dismissCheckoutRoutes();
    widget.workflow.lockCashier();
    final current = _snapshot;
    if (current == null) return;
    setState(() {
      _sessionGeneration++;
      _inventoryReady = false;
      _workspaceError = null;
      _snapshot = PosGateSnapshot(
          state: PosGateState.deviceReadyCashierLocked,
          deviceId: current.deviceId,
          merchantId: current.merchantId,
          branchId: current.branchId);
    });
  }

  Future<void> _inventory() async {
    final current = _snapshot;
    if (current?.state != PosGateState.cashierActive) return;
    if (current?.merchantId == null || current?.branchId == null) {
      setState(
          () => _workspaceError = 'Refresh device access to open checkout.');
      return;
    }
    final generation = _sessionGeneration;
    setState(() => _workspaceError = null);
    try {
      final verified = await widget.workflow.load();
      if (!mounted || generation != _sessionGeneration) return;
      if (verified.state != PosGateState.deviceReadyCashierLocked ||
          verified.deviceId != current!.deviceId ||
          verified.merchantId != current.merchantId ||
          verified.branchId != current.branchId) {
        setState(() {
          _sessionGeneration++;
          _snapshot = verified;
          _inventoryReady = false;
        });
        return;
      }
      setState(() => _inventoryReady = true);
    } catch (error) {
      if (mounted && generation == _sessionGeneration) {
        setState(() => _workspaceError = operationErrorMessage(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: SariSupplyEntry(
              role: 'POS',
              child: Column(children: [
                LinearProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading your workspace…'),
              ])));
    }
    if (_error != null) {
      return Scaffold(
          body: SariSupplyEntry(
              role: 'POS',
              child: SariSupplyStatus(message: _error!, error: true, actions: [
                FilledButton(
                    onPressed: _actionPending ? null : _reload,
                    child: const Text('Retry')),
              ])));
    }
    final snapshot = _snapshot!;
    switch (snapshot.state) {
      case PosGateState.signedOut:
        return Scaffold(
            body: SariSupplyEntry(
                role: 'POS',
                child: FilledButton(
                    onPressed: _actionPending ? null : _signIn,
                    child: Text(_actionPending
                        ? 'Signing in…'
                        : 'Sign in with Google'))));
      case PosGateState.noMerchant:
        return OwnerOnboardingGate(
          applications: widget.workflow.applications,
          memberships: widget.workflow.memberships,
          existing: snapshot.application,
          onChanged: _reload,
          onSignOut: _signOut,
        );
      case PosGateState.pendingMerchant:
        return Scaffold(
            body: SariSupplyEntry(
                role: 'POS',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Application pending review',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: _actionPending ? null : _reload,
                          child: const Text('Refresh status')),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: _actionPending ? null : _signOut,
                          child: const Text('Sign out')),
                    ])));
      case PosGateState.approvedNeedsDeviceActivation:
        return DeviceSetupScreen(
          memberships: snapshot.memberships,
          membershipRepository: widget.workflow.memberships,
          devices: widget.workflow.devices,
          onActivated: _reload,
          onSignOut: _signOut,
          onManage: _manage,
        );
      case PosGateState.deviceReadyCashierLocked:
        if (_needsPinChangeId != null) {
          return ChangeTemporaryPinScreen(
            cashierId: _needsPinChangeId!,
            onChange: widget.workflow.changePin,
            onResult: (result) => _onLoginResult(_needsPinChangeId!, result),
          );
        }
        return CashierLoginScreen(
          loadCashiers: widget.workflow.listCashiers,
          onManage: _manage,
          onLogin: widget.workflow.loginCashier,
          onResult: _onLoginResult,
        );
      case PosGateState.cashierActive:
        if (_inventoryReady) {
          final generation = _sessionGeneration;
          final session = snapshot.session;
          if (session == null) {
            return Scaffold(
                appBar: sariSupplyTaskAppBar(context, title: 'Checkout'),
                body: SariSupplyPageContent(
                    child: SariSupplyStatus(
                        message: 'Sign in to open checkout',
                        actions: [
                      FilledButton(
                          onPressed: _lock,
                          child: const Text('Cashier sign in'))
                    ])));
          }
          return CheckoutScreen(
            key: ValueKey('checkout-$generation'),
            openStore: () =>
                openInventory(snapshot.merchantId!, snapshot.branchId!),
            session: session,
            inventoryGateway: widget.workflow.deviceInventory,
            checkoutGateway: widget.workflow.checkoutGateway,
            authorize: () => widget.workflow.authorizeCheckout(session),
            grantResolver: (scope) => widget.workflow
                .readCheckoutGrant(scope.deviceId, scope.grantId),
            onLock: _lock,
            onAccessDenied: () async {
              if (mounted && generation == _sessionGeneration) {
                await widget.workflow.invalidateCheckoutAuthorization(session);
                if (mounted && generation == _sessionGeneration) {
                  await _reload();
                }
              }
            },
          );
        }
        return Scaffold(
          appBar: sariSupplyTaskAppBar(context, title: 'Checkout', actions: [
            IconButton(
                onPressed: _lock,
                tooltip: 'Lock',
                icon: const Icon(Icons.lock_outline)),
          ]),
          body: SariSupplyPageContent(
              child: _workspaceError == null
                  ? const SariSupplyStatus(
                      message: 'Checking device access…',
                      icon: Icons.hourglass_top)
                  : SariSupplyStatus(
                      message: _workspaceError!,
                      error: true,
                      actions: [
                          TextButton(
                              onPressed: snapshot.merchantId == null ||
                                      snapshot.branchId == null
                                  ? _reload
                                  : _inventory,
                              child: const Text('Retry')),
                        ])),
        );
      case PosGateState.deviceRevoked:
        return OfflineAuthBlockedScreen(
            revoked: true,
            onRetry: () async {
              await widget.workflow.clearDeviceSession();
              await _reload();
            });
      case PosGateState.offlineCredentialsExpired:
        return OfflineAuthBlockedScreen(
            revoked: false,
            onRetry: _reload,
            recoveryMessage: snapshot.recoveryMessage);
    }
  }
}
