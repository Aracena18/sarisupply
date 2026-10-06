import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_driver/main.dart';

void main() {
  for (final width in [320.0, 390.0, 600.0, 1024.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('inactive Driver at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(const SariSupplyDriverApp());
        await tester.pumpAndSettle();
        expect(find.text('No delivery workspace available'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('shows the Driver application identity', (tester) async {
    await tester.pumpWidget(const SariSupplyDriverApp());

    expect(find.text('SariSupply'), findsOneWidget);
    expect(find.text('No delivery workspace available'), findsOneWidget);
  });
}
