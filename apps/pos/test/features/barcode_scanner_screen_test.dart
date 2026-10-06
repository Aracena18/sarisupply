import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/features/checkout/barcode_scanner_screen.dart';
import '../support/checkout_fixtures.dart';

void main() {
  testWidgets('permission failure leaves manual exact barcode entry usable',
      (tester) async {
    final camera = TestCamera()..unavailable = true;
    String? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                              builder: (_) => BarcodeScannerScreen(
                                  camera: camera, authorize: () async {})));
                    },
                    child: const Text('Scan'))))));
    await tester.tap(find.text('Scan'));
    await pumpCheckout(tester);
    expect(find.text('Camera unavailable. Use a barcode or search.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Camera settings'));
    await tester.tap(find.text('Camera settings'));
    await tester.pump();
    expect(camera.settings, 1);
    await tester.enterText(find.widgetWithText(TextField, 'Barcode'), '00124');
    await tester.pump();
    await tester.tap(find.text('Use barcode'));
    await pumpCheckout(tester);
    expect(result, '00124');
    expect(camera.disposes, 1);
  });
  testWidgets('large text and landscape leave manual fallback reachable',
      (tester) async {
    tester.view.physicalSize = const Size(600, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: BarcodeScannerScreen(
            camera: TestCamera()..unavailable = true, authorize: () async {})));
    await pumpCheckout(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Search instead'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Search instead')).bottom,
        lessThanOrEqualTo(320));
  });
  testWidgets('background pauses camera and expired authorization ends scan',
      (tester) async {
    final camera = TestCamera();
    var allowed = true;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => BarcodeScannerScreen(
                                camera: camera,
                                authorize: () async {
                                  if (!allowed) throw StateError('expired');
                                }))),
                    child: const Text('Scan'))))));
    await tester.tap(find.text('Scan'));
    await pumpCheckout(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await pumpCheckout(tester);
    expect(camera.stops, greaterThan(0));
    allowed = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpCheckout(tester);
    expect(find.text('Scan barcode'), findsNothing);
    expect(camera.disposes, 1);
  });
}
