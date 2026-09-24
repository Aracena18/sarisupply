import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/main.dart';

void main() {
  testWidgets('shows the POS application identity', (tester) async {
    await tester.pumpWidget(const SariSupplyPosApp());

    expect(find.text('SariSupply POS'), findsOneWidget);
    expect(find.text('Foundation ready'), findsOneWidget);
  });
}
