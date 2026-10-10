import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/features/reports/presentation/reports_screen.dart';
import '../support/checkout_fixtures.dart';
import '../support/ui_fixtures.dart';

void main() {
  for (final layout in [
    (width: 320.0, scale: 2.0),
    (width: 390.0, scale: 1.0),
  ]) {
    testWidgets(
        'report navigation and previews at ${layout.width}px / ${layout.scale} text',
        (tester) async {
      fixtureSize(tester, layout.width);
      final fixture = CheckoutFixture();
      await tester.runAsync(() => fixture.create());
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixtureApp(
          ReportsScreen(
              store: fixture.store, branchName: 'Presentation branch'),
          scale: layout.scale));
      await pumpCheckout(tester);
      expect(find.text('Net sales'), findsNWidgets(2),
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cash drawer'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Stock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stock'));
      await pumpCheckout(tester);
      expect(find.text('Retail stock value'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sales'));
      await tester.tap(find.text('Sales'));
      await pumpCheckout(tester);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Backup'));
      await tester.tap(find.text('Backup'));
      await pumpCheckout(tester);
      expect(find.text('Backup password'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Printer'));
      await tester.tap(find.text('Printer'));
      await pumpCheckout(tester);
      expect(find.text('58 mm'), findsOneWidget);
      await tester.ensureVisible(find.text('80 mm'));
      await tester.tap(find.text('80 mm'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview test receipt'));
      await tester.tap(find.text('Preview test receipt'));
      await tester.pumpAndSettle();
      expect(find.text('80 mm · 42 columns'), findsOneWidget);
      expect(find.text('Copy receipt text'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      expect(find.text('Receipt layout'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
