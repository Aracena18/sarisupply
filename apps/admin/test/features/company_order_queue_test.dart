import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/sarisupply_company.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

CompanyRecord order({
  String id = 'order-1042',
  String status = 'submitted',
  String receiptStatus = 'awaitingDelivery',
}) =>
    CompanyRecord({
      'id': id,
      'status': status,
      'receiptStatus': receiptStatus,
      'storeName': 'Beta Store',
      'branchName': 'Main branch',
      'address': 'Tawantawan, Baguio District',
    });

void main() {
  test('queue tabs group the current order lifecycle without changing it', () {
    expect(
      companyOrderQueueTab(order(status: 'submitted')),
      CompanyOrderQueueTab.awaiting,
    );
    expect(
      companyOrderQueueTab(order(status: 'awaitingConfirmation')),
      CompanyOrderQueueTab.awaiting,
    );
    expect(
      companyOrderQueueTab(order(status: 'accepted')),
      CompanyOrderQueueTab.accepted,
    );
    expect(
      companyOrderQueueTab(order(status: 'picking')),
      CompanyOrderQueueTab.accepted,
    );
    expect(
      companyOrderQueueTab(order(status: 'packed')),
      CompanyOrderQueueTab.ready,
    );
    expect(
      companyOrderQueueTab(order(status: 'dispatched')),
      CompanyOrderQueueTab.onRoute,
    );
    expect(
      companyOrderQueueTab(
        order(status: 'dispatched', receiptStatus: 'confirmed'),
      ),
      CompanyOrderQueueTab.completed,
    );
    expect(
      companyOrderQueueTab(
        order(status: 'dispatched', receiptStatus: 'needsReview'),
      ),
      CompanyOrderQueueTab.onRoute,
    );
    expect(companyOrderQueueTab(order(status: 'inTransit')),
        CompanyOrderQueueTab.onRoute);
    expect(companyOrderQueueTab(order(status: 'cancelled')), isNull);
    expect(companyOrderQueueTab(order(status: 'rejected')), isNull);
  });

  test('local search matches id, store, branch and location case-insensitively',
      () {
    final record = order();
    expect(companyOrderMatchesSearch(record, '1042'), isTrue);
    expect(companyOrderMatchesSearch(record, 'beta'), isTrue);
    expect(companyOrderMatchesSearch(record, 'main branch'), isTrue);
    expect(companyOrderMatchesSearch(record, 'baguio'), isTrue);
    expect(companyOrderMatchesSearch(record, 'unmatched'), isFalse);
    expect(companyOrderMatchesSearch(record, '  '), isTrue);
  });

  for (final width in [320.0, 390.0, 432.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('flat order row fits $width logical px at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const storeName = 'Tawantawan Neighborhood Grocery and Sari-Sari Store';
        const amount = '₱1,240.00';
        await tester.pumpWidget(
          MaterialApp(
            theme: SariSupplyTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: SingleChildScrollView(
                    child: CompanyOrderQueueRow(
                      order: order(),
                      storeName: storeName,
                      orderTime: '11:38 AM',
                      amount: amount,
                      statusLabel: 'Awaiting',
                      statusColor: SariSupplyColors.orange700,
                      statusBackgroundColor: SariSupplyColors.orange50,
                      details: const Text('Current order details'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final name = tester.renderObject<RenderParagraph>(
          find.text(storeName),
        );
        final money = tester.renderObject<RenderParagraph>(find.text(amount));
        expect(name.didExceedMaxLines, isFalse);
        expect(money.didExceedMaxLines, isFalse);
        expect(
          tester.getRect(find.text(storeName)).overlaps(
                tester.getRect(find.text(amount)),
              ),
          isFalse,
        );
      });
    }
  }

  testWidgets('long totals remain complete without overflowing a phone row',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const amount = '₱999,999,999,999,999.00';
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      home: Scaffold(
          body: CompanyOrderQueueRow(
        order: order(),
        storeName: 'Beta Store',
        orderTime: 'Oct 7, 2026 · 11:38 AM',
        amount: amount,
        statusLabel: 'Out for delivery',
        statusColor: SariSupplyColors.info,
        statusBackgroundColor: SariSupplyColors.ink50,
      )),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
        tester
            .renderObject<RenderParagraph>(find.text(amount))
            .didExceedMaxLines,
        isFalse);
  });

  testWidgets(
      'empty queue centers its message and action in the remaining viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      home: Scaffold(
        bottomNavigationBar: const SizedBox(height: 80),
        body: CustomScrollView(slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: CompanyOrderQueueEmptyState(
                message: 'No received orders',
                explanation: 'Other queues have orders you can work on.',
                action: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View on route orders')),
              ),
            ),
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    final empty = tester.getRect(find.byType(CompanyOrderQueueEmptyState));
    final icon = tester.getRect(find.byIcon(Icons.inbox_outlined));
    final action = tester.getRect(find.byType(FilledButton));
    expect(action.center.dx, closeTo(empty.center.dx, 1));
    expect((icon.top + action.bottom) / 2, closeTo(empty.center.dy, 1));
    expect(tester.widget<Text>(find.text('No received orders')).textAlign,
        TextAlign.center);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an order row opens its existing detail content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SariSupplyTheme.light,
        home: Scaffold(
          body: CompanyOrderQueueRow(
            order: order(),
            storeName: 'Beta Store',
            orderTime: '11:38 AM',
            amount: '₱5.00',
            statusLabel: 'Awaiting',
            statusColor: SariSupplyColors.orange700,
            statusBackgroundColor: SariSupplyColors.orange50,
            details: const Text('Current order details'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current order details'), findsNothing);
    await tester.tap(find.text('Beta Store'));
    await tester.pumpAndSettle();
    expect(find.text('Current order details'), findsOneWidget);
  });
}
