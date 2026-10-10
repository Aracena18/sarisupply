import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/company_rider_route.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

Map<String, Object?> stop(int sequence, {bool complete = false}) => {
      'id': 'stop-$sequence',
      'sequence': sequence,
      'destinationName': 'Store $sequence',
      'destinationAddress': 'Davao City',
      'contactPerson': 'Store owner',
      'contactPhone': '09123456789',
      'status': complete ? 'partiallyDelivered' : 'pending',
      'items': [
        {
          'productName': 'Rice',
          'quantityOrdered': 2,
          'unitName': 'bag',
          'unitCostCentavos': 10000
        },
      ],
      'amountDueCentavos': 15000,
      if (complete) 'proof': {'cashCollectedCentavos': 5000},
      if (complete) 'localPending': true,
    };

CompanyRecord run(List<Map<String, Object?>> stops,
        {String status = 'dispatched'}) =>
    CompanyRecord({'id': 'run-1', 'status': status, 'stops': stops});

void main() {
  testWidgets(
      'company rider opens directions and details for the next ordered stop',
      (tester) async {
    Map<String, Object?>? recorded;
    Map<String, Object?>? destination;
    final assigned = run([stop(2), stop(1)]);
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      home: CompanyRiderRoute(
        companyName: 'SariSupply',
        runs: [assigned],
        onRefresh: () async {},
        onDirections: (s) => destination = s,
        onProof: (r, s) {
          expect(r, same(assigned));
          recorded = s;
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('My Route'), findsOneWidget);
    expect(find.text('Store 1'), findsOneWidget);
    expect(find.text('COD ₱150.00'), findsOneWidget);
    await tester.tap(find.text('Open directions'));
    await tester.pumpAndSettle();
    expect(destination?['id'], 'stop-1');
    await tester.tap(find.text('View stop details'));
    await tester.pumpAndSettle();
    expect(find.text('Stop 1 of 2'), findsOneWidget);
    expect(find.text('Step 2 of 5'), findsOneWidget);
    expect(recorded, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'denied actions stay disabled and pending proof is not offered again',
      (tester) async {
    var proofs = 0;
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      home: CompanyRiderRoute(
        companyName: 'SariSupply',
        runs: [
          run([stop(1, complete: true), stop(2)])
        ],
        actionsEnabled: false,
        error: 'Your access has changed.',
        onRefresh: () async {},
        onDirections: (_) {},
        onProof: (run, stop) => proofs++,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Store 2'), findsOneWidget);
    expect(find.text('1 of 2 stops recorded'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(proofs, 0);
    expect(find.text('Your access has changed.'), findsOneWidget);
    await tester.tap(find.text('Recorded stops · 1'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.text('Saved on this phone · Waiting to sync'));
    await tester.pumpAndSettle();
    expect(find.text('Partial delivery recorded'), findsOneWidget);
    expect(find.text('Saved on this phone · Waiting to sync'), findsOneWidget);
  });

  testWidgets(
      'QR delivery cue skips cash collection and preserves pending payment',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      home: CompanyRiderRoute(
        companyName: 'SariSupply',
        runs: [
          run([
            {...stop(1), 'paymentMethod': 'qr', 'amountDueCentavos': 20000}
          ])
        ],
        onRefresh: () async {},
        onDirections: (_) {},
        onProof: (_, __) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('QR payment pending'), findsOneWidget);
    await tester.tap(find.text('View stop details'));
    await tester.pumpAndSettle();
    for (final action in [
      'Open directions',
      'Start delivery',
      'Confirm items'
    ]) {
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
    }
    expect(find.text('Step 4 of 4'), findsOneWidget);
    expect(find.text('Confirm collection'), findsNothing);
    expect(find.text('Record proof'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('awaiting confirmation'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('awaiting confirmation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'empty company route keeps refresh and account recovery on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var refreshes = 0;
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: CompanyRiderRoute(
        companyName: 'SariSupply',
        runs: const [],
        onRefresh: () async {
          refreshes++;
        },
        onDirections: (_) {},
        onProof: (run, stop) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No active deliveries'), findsOneWidget);
    expect(find.text('Record delivery'), findsNothing);
    await tester.tap(find.byTooltip('Refresh assignments'));
    expect(refreshes, 1);
    expect(tester.takeException(), isNull);
  });
}
