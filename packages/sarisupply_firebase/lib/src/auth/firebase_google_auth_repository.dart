import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

import 'google_identity_gateway.dart';

final class FirebaseGoogleAuthRepository implements AuthRepository {
  FirebaseGoogleAuthRepository({
    required FirebaseAuth auth,
    GoogleIdentityGateway? gateway,
    String serverClientId = '',
    bool? isWeb,
  })  : _auth = auth,
        _gateway = gateway ?? GoogleSignInIdentityGateway(),
        _serverClientId = serverClientId,
        _isWeb = isWeb ?? kIsWeb {
    if (auth.app.name != defaultFirebaseAppName) {
      throw StateError(
          'Human authentication requires the default Firebase app');
    }
  }

  final FirebaseAuth _auth;
  final GoogleIdentityGateway _gateway;
  final String _serverClientId;
  final bool _isWeb;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().map((user) {
      return user == null ? null : _toAuthUser(user);
    });
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final UserCredential credential;
    if (_isWeb) {
      credential = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      if (_serverClientId.trim().isEmpty) {
        throw StateError('GOOGLE_SERVER_CLIENT_ID is required on Android');
      }
      final idToken = await _gateway.idToken(_serverClientId);
      credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    }

    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase sign-in did not return a user');
    }
    return _toAuthUser(user);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (!_isWeb) {
      await _gateway.signOut();
    }
  }

  static AuthUser _toAuthUser(User user) {
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      emailVerified: user.emailVerified,
    );
  }
}
