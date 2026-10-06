import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import '../../merchant_review/presentation/merchant_review_list_screen.dart';

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate(
      {super.key,
      required this.auth,
      required this.access,
      required this.reviews,
      this.procurement});
  final AuthRepository auth;
  final AdminAccessRepository access;
  final AdminReviewRepository reviews;
  final ProcurementGateway? procurement;
  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  late Stream<AuthUser?> _authStream;
  String? _checkedUid, _error;
  Future<bool>? _accessCheck;
  bool _pending = false;
  @override
  void initState() {
    super.initState();
    _authStream = widget.auth.authStateChanges();
  }

  @override
  void didUpdateWidget(covariant AdminAuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth || oldWidget.access != widget.access) {
      _authStream = widget.auth.authStateChanges();
      _checkedUid = null;
      _accessCheck = null;
    }
  }

  Future<void> _authenticate({bool signOut = false}) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      if (signOut) {
        await widget.auth.signOut();
      } else {
        await widget.auth.signInWithGoogle();
      }
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Widget _entry(Widget child) => Scaffold(
      body: SariSupplyEntry(
          role: 'Admin',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            child,
            if (_error != null) ...[
              const SizedBox(height: 16),
              SariSupplyStatus(message: _error!, error: true)
            ],
          ])));
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthUser?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _entry(SariSupplyStatus(
              message: 'Unable to check sign-in.',
              error: true,
              actions: [
                TextButton(
                    onPressed: () => setState(() {
                          _authStream = widget.auth.authStateChanges();
                          _checkedUid = null;
                          _accessCheck = null;
                        }),
                    child: const Text('Retry'))
              ]));
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return _entry(const Column(children: [
            LinearProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking sign-in…')
          ]));
        }
        final user = snapshot.data;
        if (user == null) {
          _checkedUid = null;
          _accessCheck = null;
          return _entry(FilledButton(
              onPressed: _pending ? null : () => _authenticate(),
              child: Text(_pending ? 'Signing in…' : 'Sign in with Google')));
        }
        if (_checkedUid != user.uid) {
          _checkedUid = user.uid;
          _accessCheck = widget.access.isActiveAdmin();
        }
        return FutureBuilder<bool>(
            future: _accessCheck,
            builder: (context, access) {
              if (access.connectionState != ConnectionState.done) {
                return _entry(const Column(children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking Admin access…')
                ]));
              }
              if (access.hasError) {
                return _entry(SariSupplyStatus(
                    message: 'Unable to check Admin access',
                    error: true,
                    actions: [
                      FilledButton(
                          onPressed: _pending
                              ? null
                              : () => setState(() =>
                                  _accessCheck = widget.access.isActiveAdmin()),
                          child: const Text('Retry')),
                      TextButton(
                          onPressed: _pending
                              ? null
                              : () => _authenticate(signOut: true),
                          child: const Text('Sign out')),
                    ]));
              }
              if (access.data != true) {
                return _entry(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Access denied',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      const SariSupplyStatus(
                          message:
                              'This Google account is not an active SariSupply Admin.',
                          icon: Icons.lock_outline),
                      const SizedBox(height: 24),
                      TextButton(
                          onPressed: _pending
                              ? null
                              : () => _authenticate(signOut: true),
                          child: Text(_pending ? 'Signing out…' : 'Sign out')),
                    ]));
              }
              return MerchantReviewListScreen(
                  reviews: widget.reviews,
                  onSignOut: widget.auth.signOut,
                  procurement: widget.procurement);
            });
      });
}
