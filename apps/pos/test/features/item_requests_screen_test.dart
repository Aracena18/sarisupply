import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/item_requests_screen.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  testWidgets('Store Owner can request an item and see the refreshed history',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var created = false;
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      home: ItemRequestsScreen(
        store: true,
        read: (_) async => CompanyPage(
          records: created
              ? [
                  CompanyRecord({
                    'id': 'request-1',
                    'name': 'Requested rice',
                    'quantity': 2,
                    'unit': 'bag',
                    'status': 'submitted',
                  })
                ]
              : [],
          nextCursor: null,
          hasMore: false,
        ),
        create: () async {
          created = true;
        },
        respond: (request, close) async {
          fail('Store cannot respond to requests');
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Request an item'), findsOneWidget);
    await tester.tap(find.text('Request an item'));
    await tester.pumpAndSettle();
    expect(created, isTrue);
    expect(find.text('Requested rice'), findsOneWidget);
    expect(find.text('2 bag · Submitted'), findsOneWidget);
    expect(find.text('Respond'), findsNothing);
    expect(find.text('Close request'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
