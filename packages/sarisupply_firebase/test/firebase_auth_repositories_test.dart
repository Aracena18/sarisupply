import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class _FakeApp extends Fake implements FirebaseApp {
  _FakeApp(this.name);

  @override
  final String name;
}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'firebase-uid';

  @override
  String? get email => 'owner@example.com';

  @override
  String? get displayName => 'Owner';

  @override
  bool get emailVerified => true;
}

class _FakeCredential extends Fake implements UserCredential {
  @override
  User? get user => _FakeUser();
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  _FakeFirebaseAuth(String appName) : app = _FakeApp(appName);

  @override
  final FirebaseApp app;

  AuthCredential? credential;
  String? customToken;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    this.credential = credential;
    return _FakeCredential();
  }

  @override
  Future<UserCredential> signInWithCustomToken(String token) async {
    customToken = token;
    return _FakeCredential();
  }
}

class _FakeGoogleGateway implements GoogleIdentityGateway {
  String? requestedClientId;

  @override
  Future<String> idToken(String serverClientId) async {
    requestedClientId = serverClientId;
    return 'google-id-token';
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  test('native Google sign-in exchanges the ID token for a human user',
      () async {
    final auth = _FakeFirebaseAuth(defaultFirebaseAppName);
    final gateway = _FakeGoogleGateway();
    final repository = FirebaseGoogleAuthRepository(
      auth: auth,
      gateway: gateway,
      serverClientId: 'web-oauth-client',
      isWeb: false,
    );

    final user = await repository.signInWithGoogle();

    expect(gateway.requestedClientId, 'web-oauth-client');
    expect(auth.credential, isA<OAuthCredential>());
    expect(user.uid, 'firebase-uid');
    expect(user.email, 'owner@example.com');
    expect(user.emailVerified, isTrue);
  });

  test('native Google sign-in requires its server client ID', () async {
    final repository = FirebaseGoogleAuthRepository(
      auth: _FakeFirebaseAuth(defaultFirebaseAppName),
      gateway: _FakeGoogleGateway(),
      serverClientId: '',
      isWeb: false,
    );

    await expectLater(repository.signInWithGoogle(), throwsStateError);
  });

  test('device custom token cannot use the human Firebase app', () {
    expect(
      () => FirebaseDeviceAuthRepository(
        auth: _FakeFirebaseAuth(defaultFirebaseAppName),
      ),
      throwsStateError,
    );
  });

  test('device custom token signs in only on the named device app', () async {
    final auth = _FakeFirebaseAuth(FirebaseBootstrap.deviceAppName);
    final repository = FirebaseDeviceAuthRepository(auth: auth);

    final uid = await repository.signInWithCustomToken('device-token');

    expect(uid, 'firebase-uid');
    expect(auth.customToken, 'device-token');
  });
}
