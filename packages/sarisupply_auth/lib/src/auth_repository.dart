import 'auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  Future<AuthUser> signInWithGoogle();

  Future<void> signOut();
}
