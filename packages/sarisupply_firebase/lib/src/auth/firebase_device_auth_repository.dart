import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../bootstrap/firebase_bootstrap.dart';

final class FirebaseDeviceAuthRepository {
  FirebaseDeviceAuthRepository({required FirebaseAuth auth}) : _auth = auth {
    if (auth.app.name != FirebaseBootstrap.deviceAppName) {
      throw StateError('Device authentication requires the named device app');
    }
  }

  factory FirebaseDeviceAuthRepository.forApp(FirebaseApp deviceApp) {
    if (deviceApp.name != FirebaseBootstrap.deviceAppName) {
      throw StateError('Device authentication requires the named device app');
    }
    return FirebaseDeviceAuthRepository(
      auth: FirebaseAuth.instanceFor(app: deviceApp),
    );
  }

  final FirebaseAuth _auth;

  Future<String> signInWithCustomToken(String token) async {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'must not be empty');
    }
    final credential = await _auth.signInWithCustomToken(token);
    final uid = credential.user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Device sign-in did not return a UID');
    }
    return uid;
  }
}
