import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/app/pos_app_gate.dart';
import 'package:sarisupply_pos/main.dart';

class _SignedOutWorkflow extends Fake implements PosWorkflow {
  @override
  Future<PosGateSnapshot> load() async =>
      const PosGateSnapshot(state: PosGateState.signedOut);
}

void main() {
  testWidgets('shows POS sign in when signed out', (tester) async {
    await tester.pumpWidget(SariSupplyPosApp(workflow: _SignedOutWorkflow()));
    await tester.pumpAndSettle();

    expect(find.text('SariSupply POS'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
