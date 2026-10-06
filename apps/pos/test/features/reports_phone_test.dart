import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/features/reports/presentation/reports_screen.dart';
import '../support/checkout_fixtures.dart';
import '../support/ui_fixtures.dart';

void main() {
  testWidgets('reports remain readable on a 320px phone at 200 percent text',
      (tester) async {
    fixtureSize(tester, 320);
    final fixture = CheckoutFixture();
    await tester.runAsync(() => fixture.create());
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixtureApp(
        ReportsScreen(store: fixture.store, branchName: 'Presentation branch'),
        scale: 2));
    await pumpCheckout(tester);
    expect(find.text('Net Sales'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Valuation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valuation'));
    await pumpCheckout(tester);
    expect(find.text('Retail Inventory Value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
