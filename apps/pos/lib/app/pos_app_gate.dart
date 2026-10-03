import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import '../features/cashier_auth/domain/cashier_login_service.dart';
import '../features/cashier_auth/presentation/cashier_login_screen.dart';
import '../features/cashier_auth/presentation/change_temporary_pin_screen.dart';
import '../features/cashier_auth/presentation/offline_auth_blocked_screen.dart';
import '../features/device_setup/presentation/device_setup_screen.dart';
import '../features/owner_onboarding/presentation/owner_onboarding_gate.dart';

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
  });

  final PosGateState state;
  final MerchantApplication? application;
  final List<MerchantMembership> memberships;
  final String? deviceId;
  final String? merchantId;
  final String? branchId;
  final CashierSession? session;
}

abstract interface class PosWorkflow {
  MerchantApplicationRepository get applications;
  MembershipRepository get memberships;
  DeviceRepository get devices;
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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = await widget.workflow.load();
      if (mounted) {
        setState(() {
          _snapshot = next;
          _needsPinChangeId = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _signIn() async {
    try {
      await widget.workflow.signIn();
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = 'Sign-in failed: $error');
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.workflow.signOutHuman();
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to sign out: $error');
    }
  }

  void _onLoginResult(String cashierId, CashierLoginResult result) {
    final current = _snapshot;
    if (current == null) return;
    setState(() {
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
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('SariSupply POS')),
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Unable to load POS: $_error'),
            TextButton(onPressed: _reload, child: const Text('Retry')),
          ])));
    }
    final snapshot = _snapshot!;
    switch (snapshot.state) {
      case PosGateState.signedOut:
        return Scaffold(
            appBar: AppBar(title: const Text('SariSupply POS')),
            body: Center(
                child: FilledButton(
                    onPressed: _signIn,
                    child: const Text('Sign in with Google'))));
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
            appBar: AppBar(
                title: const Text('Application pending review'),
                actions: [
                  TextButton(onPressed: _signOut, child: const Text('Sign out'))
                ]),
            body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Your store application is waiting for review.'),
              TextButton(
                  onPressed: _reload, child: const Text('Refresh status')),
            ])));
      case PosGateState.approvedNeedsDeviceActivation:
        return DeviceSetupScreen(
          memberships: snapshot.memberships,
          membershipRepository: widget.workflow.memberships,
          devices: widget.workflow.devices,
          onActivated: _reload,
          onSignOut: _signOut,
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
          onLogin: widget.workflow.loginCashier,
          onResult: _onLoginResult,
        );
      case PosGateState.cashierActive:
        return Scaffold(
            appBar: AppBar(title: const Text('Cashier active')),
            body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  'Cashier ${snapshot.session?.cashierId ?? ''} is signed in.'),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => setState(() => _snapshot = PosGateSnapshot(
                        state: PosGateState.deviceReadyCashierLocked,
                        deviceId: snapshot.deviceId,
                        merchantId: snapshot.merchantId,
                        branchId: snapshot.branchId,
                      )),
                  child: const Text('End cashier session')),
            ])));
      case PosGateState.deviceRevoked:
        return OfflineAuthBlockedScreen(
            revoked: true,
            onRetry: () async {
              await widget.workflow.clearDeviceSession();
              await _reload();
            });
      case PosGateState.offlineCredentialsExpired:
        return OfflineAuthBlockedScreen(revoked: false, onRetry: _reload);
    }
  }
}
