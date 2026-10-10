import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/item_requests_screen.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  Future<void> showRequests(
      WidgetTester tester, Future<CompanyPage> Function(String?) read) async {
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      home: ItemRequestsScreen(
        store: false,
        read: read,
        create: () async {},
        respond: (request, close) async {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Admin item requests render and scroll inside the page wrapper',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showRequests(
        tester,
        (_) async => CompanyPage(
              records: List.generate(
                  8,
                  (i) => CompanyRecord({
                        'id': 'request-$i',
                        'name': 'Requested item $i',
                        'quantity': 2,
                        'unit': 'pack',
                        'status': 'submitted',
                        'storeName': 'Beta Store',
                        'branchName': 'Main branch',
                        'contact': 'Store Owner',
                        'phone': '09123456789',
                      })),
              nextCursor: null,
              hasMore: false,
            ));
    expect(tester.takeException(), isNull);
    expect(find.text('Requested item 0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Requested item 7'), 400,
        scrollable: find.byType(Scrollable));
    expect(find.text('Requested item 7').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'empty requests display an explicit state instead of a blank page',
      (tester) async {
    await showRequests(
        tester,
        (_) async =>
            CompanyPage(records: const [], nextCursor: null, hasMore: false));
    expect(tester.takeException(), isNull);
    expect(find.text('No item requests yet.'), findsOneWidget);
  });

  testWidgets('failed reads display recovery and refresh reloads requests',
      (tester) async {
    var reads = 0;
    await showRequests(tester, (_) async {
      if (reads++ == 0) throw StateError('Read failed');
      return CompanyPage(records: const [], nextCursor: null, hasMore: false);
    });
    expect(tester.takeException(), isNull);
    expect(find.text('Unable to complete this action. Try again.'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Refresh requests'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(
        find.text('Unable to complete this action. Try again.'), findsNothing);
  });
}
