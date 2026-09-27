import 'package:google_sign_in/google_sign_in.dart';

abstract interface class GoogleIdentityGateway {
  Future<String> idToken(String serverClientId);

  Future<void> signOut();
}

final class GoogleSignInIdentityGateway implements GoogleIdentityGateway {
  static Future<void>? _initialization;
  static String? _initializedClientId;

  @override
  Future<String> idToken(String serverClientId) async {
    if (_initializedClientId != null &&
        _initializedClientId != serverClientId) {
      throw StateError('Google Sign-In is configured for another environment');
    }
    _initializedClientId = serverClientId;
    _initialization ??= GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
    await _initialization;

    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Google Sign-In did not return an ID token');
    }
    return token;
  }

  @override
  Future<void> signOut() async {
    if (_initialization != null) {
      await GoogleSignIn.instance.signOut();
    }
  }
}
