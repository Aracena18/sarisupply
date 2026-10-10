import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/company_delivery_queue.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

CompanyRecord run(String status, {String rider = 'rider@example.com'}) =>
    CompanyRecord({
      'id': 'run-12345678-1234-1234-1234-123456789abc',
      'status': status,
      'driverId': 'assigned-rider',
      'driverName': rider,
      'stops': [
        {'id': 'stop-1'},
      ],
    });

void main() {
  test('assigned drafts stay in Drafts until dispatch', () {
    expect(companyDeliveryQueue(run('draft')), CompanyDeliveryQueue.drafts);
    for (final status in ['dispatched', 'inTransit']) {
      expect(companyDeliveryQueue(run(status)), CompanyDeliveryQueue.onRoute);
    }
    for (final status in ['completed', 'cancelled']) {
      expect(companyDeliveryQueue(run(status)), CompanyDeliveryQueue.history);
    }
  });

  for (final layout in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('delivery identity stays readable at $layout', (tester) async {
      tester.view.physicalSize = Size(layout.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var expanded = false;
      const rider = 'tawantawan.delivery.rider@example.com';
      const destination = 'Tawantawan Neighborhood Grocery and Sari-Sari Store';
      await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(layout.$2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(builder: (context, setState) {
                return CompanyDeliveryQueueRow(
                  run: run('draft', rider: rider),
                  destination: destination,
                  orderCount: 1,
                  statusLabel: 'Ready to dispatch',
                  statusKind: SsStatus.warning,
                  recordedAt: DateTime(2026, 10, 7, 13, 20),
                  expanded: expanded,
                  onToggle: () => setState(() => expanded = !expanded),
                  details: const Text('Delivery details'),
                );
              }),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in [destination, 'Rider · $rider']) {
        expect(
            tester
                .renderObject<RenderParagraph>(find.text(label))
                .didExceedMaxLines,
            isFalse);
      }
      expect(find.text('Delivery #56789abc'), findsOneWidget);
      expect(find.text('Delivery details'), findsNothing);
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
      expect(find.text('Delivery details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
