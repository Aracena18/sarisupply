import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

import '../../merchant_review/presentation/merchant_review_list_screen.dart';

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({
    super.key,
    required this.auth,
    required this.access,
    required this.reviews,
  });

  final AuthRepository auth;
  final AdminAccessRepository access;
  final AdminReviewRepository reviews;

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  late Stream<AuthUser?> _authStream;
  String? _checkedUid;
  Future<bool>? _accessCheck;
  bool _signingIn = false;

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

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      await widget.auth.signInWithGoogle();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthUser?>(
        stream: _authStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Sign-in error: ${snapshot.error}'));
          }
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) {
            _checkedUid = null;
            _accessCheck = null;
            return Center(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('SariSupply Admin'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _signingIn ? null : _signIn,
                  child: const Text('Sign in with Google'),
                ),
              ],
            ));
          }
          if (_checkedUid != user.uid) {
            _checkedUid = user.uid;
            _accessCheck = widget.access.isActiveAdmin();
          }
          return FutureBuilder<bool>(
            future: _accessCheck,
            builder: (context, access) {
              if (access.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (access.hasError) {
                return Center(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Unable to check Admin access: ${access.error}'),
                    TextButton(
                        onPressed: () => setState(
                            () => _accessCheck = widget.access.isActiveAdmin()),
                        child: const Text('Retry')),
                  ],
                ));
              }
              if (access.data != true) {
                return Center(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Access denied'),
                    const SizedBox(height: 8),
                    const Text(
                        'This Google account is not an active SariSupply Admin.'),
                    TextButton(
                        onPressed: widget.auth.signOut,
                        child: const Text('Sign out')),
                  ],
                ));
              }
              return MerchantReviewListScreen(
                  reviews: widget.reviews, onSignOut: widget.auth.signOut);
            },
          );
        },
      );
}
