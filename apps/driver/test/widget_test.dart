import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_driver/main.dart';

void main() {
  testWidgets('shows the Driver application identity', (tester) async {
    await tester.pumpWidget(const SariSupplyDriverApp());

    expect(find.text('SariSupply Driver'), findsOneWidget);
    expect(find.text('Foundation ready'), findsOneWidget);
  });
}
