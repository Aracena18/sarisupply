import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_admin/main.dart';

class _SignedOutAuth extends Fake implements AuthRepository {
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(null);
}

class _Access extends Fake implements AdminAccessRepository {}

class _Reviews extends Fake implements AdminReviewRepository {}

void main() {
  testWidgets('shows Admin sign in when signed out', (tester) async {
    await tester.pumpWidget(SariSupplyAdminApp(
      auth: _SignedOutAuth(),
      access: _Access(),
      reviews: _Reviews(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('SariSupply'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
