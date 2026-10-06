import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/app/pos_app_gate.dart';
import 'package:sarisupply_pos/main.dart';

class _SignedOutWorkflow extends Fake implements PosWorkflow {
  @override
  Future<PosGateSnapshot> load() async =>
      const PosGateSnapshot(state: PosGateState.signedOut);
}

void main() {
  testWidgets('startup failure shows safe branded configuration state',
      (tester) async {
    await tester.pumpWidget(const SariSupplyPosApp());
    expect(tester.takeException(), isNotNull);
    await tester.pumpAndSettle();
    expect(find.text('SariSupply'), findsOneWidget);
    expect(find.text('POS setup is incomplete. Contact your administrator.'),
        findsOneWidget);
    expect(find.textContaining('firebase'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows POS sign in when signed out', (tester) async {
    await tester.pumpWidget(SariSupplyPosApp(workflow: _SignedOutWorkflow()));
    await tester.pumpAndSettle();

    expect(find.text('SariSupply'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
