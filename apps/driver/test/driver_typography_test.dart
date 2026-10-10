import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/company_rider_route.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'company_rider_route_test.dart' as fixture;

void main() {
  for (final size in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('Driver route and stop typography ${size.$1}px at ${size.$2}x',
        (tester) async {
      tester.view.physicalSize = Size(size.$1, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(size.$2)),
          child: child!,
        ),
        home: CompanyRiderRoute(
          companyName: 'SariSupply',
          runs: [
            fixture.run([fixture.stop(1), fixture.stop(2)])
          ],
          onRefresh: () async {},
          onDirections: (_) {},
          onProof: (_, __) {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('My Route'), findsOneWidget);
      expect(find.text('Store 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('View stop details'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View stop details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View stop details'));
      await tester.pumpAndSettle();
      expect(find.text('Stop 1 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final action in [
        'Open directions',
        'Start delivery',
        'Confirm items'
      ]) {
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Step 4 of 5'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '150.00');
      await tester.tap(find.text('Confirm collection'));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(find.text('Record proof'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
