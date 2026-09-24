import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_admin/main.dart';

void main() {
  testWidgets('shows the Admin application identity', (tester) async {
    await tester.pumpWidget(const SariSupplyAdminApp());

    expect(find.text('SariSupply Admin'), findsOneWidget);
    expect(find.text('Foundation ready'), findsOneWidget);
  });
}
