import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/company_order_details.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

CompanyRecord order(String status) => CompanyRecord({
      'id': 'order-1',
      'status': status,
      'address': 'Store delivery address',
      'lines': [
        {'name': 'Rice', 'quantity': 2, 'unit': 'bag', 'priceCentavos': 350}
      ],
      'proposedLines': [
        {'name': 'Rice', 'quantity': 1, 'unit': 'bag', 'priceCentavos': 350}
      ],
      'changeReason': 'Only one bag available',
    });

Widget page(String status, ValueChanged<String> onAction,
        {bool enabled = true, double scale = 1}) =>
    MaterialApp(
      theme: SariSupplyTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
          body: CompanyOrderDetails(
        order: order(status),
        storeName: 'Beta Store',
        statusLabel: status,
        totalCentavos: 700,
        balanceCentavos: 700,
        actionsEnabled: enabled,
        cached: !enabled,
        onAction: onAction,
        onResolveReceipt: () {},
        onClose: () {},
      )),
    );

void main() {
  testWidgets(
      'next action follows fulfillment stage and payment stays separate',
      (tester) async {
    String? action;
    for (final entry in {
      'submitted': ('Accept order', 'acceptOrder'),
      'accepted': ('Start picking', 'startPicking'),
      'picking': ('Confirm packing', 'packOrder'),
    }.entries) {
      await tester.pumpWidget(page(entry.key, (value) => action = value));
      await tester.pumpAndSettle();
      expect(find.text('2 bag × ₱3.50'), findsOneWidget);
      expect(find.text('₱7.00'), findsNWidgets(2));
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.ensureVisible(find.text(entry.value.$1));
      await tester.tap(find.text(entry.value.$1));
      expect(action, entry.value.$2);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
        page('awaitingConfirmation', (_) => fail('Must await store approval')));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('1 bag × ₱3.50'), findsOneWidget);
    expect(find.text('Only one bag available'), findsOneWidget);
  });

  testWidgets('small phone large text keeps cached actions disabled',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(page(
        'picking', (_) => fail('Cached order must not mutate'),
        enabled: false, scale: 2));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    for (final button
        in tester.widgetList<OutlinedButton>(find.byType(OutlinedButton))) {
      expect(button.onPressed, isNull);
    }
    await tester.tap(find.text('Delivery & payment'));
    await tester.pumpAndSettle();
    expect(find.text('Order ID · order-1'), findsOneWidget);
    await tester.ensureVisible(find.text('Confirm QR payment'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
