final class AuthUser {
  const AuthUser({
    required this.uid,
    required this.emailVerified,
    this.email,
    this.displayName,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
}
