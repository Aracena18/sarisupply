import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/checkout_fixtures.dart';
import '../support/ui_fixtures.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  testWidgets('phone shift shows debt and refund queues at 200 percent text',
      (tester) async {
    fixtureSize(tester, 320);
    final f = CheckoutFixture();
    await tester.runAsync(() async {
      await f.create();
      await f.store.checkout.saveCustomer(CustomerAccount(
          id: 'customer',
          name: 'Rosa',
          phone: '09170000000',
          creditLimitCentavos: 5000,
          balanceCentavos: 1000));
      await f.store.checkout.recordDebtRepayment(DebtRepayment(
          id: 'repayment',
          customerId: 'customer',
          amountCentavos: 500,
          tenderKind: 'cash',
          occurredAt: f.now,
          shiftId: 'shift',
          cashierId: 'c'));
      final line = CartLine(
          productId: 'p',
          sku: 'MILK',
          name: 'Milk',
          unit: 'piece',
          factor: 1,
          priceCentavos: 1250,
          quantity: 1,
          catalogSequence: 1,
          catalogRevision: 1);
      final sale = CheckoutSale(
          id: 'sale',
          scope: f.scope,
          shiftId: 'shift',
          ordinal: 3,
          occurredAt: f.now,
          merchantName: 'Store',
          branchName: 'Branch',
          lines: [line],
          tender: const Tender.cash(1500));
      await f.store.checkout.saveDraft(CheckoutDraft(
          scope: f.scope, shiftId: 'shift', lines: [line], frozenSale: sale));
      await f.store.checkout.completeSale(sale);
      await f.store.checkout
          .markReceiptSeen(f.scope.deviceId, f.scope.cashierId, sale.id);
      await f.store.checkout.recordRefund(RefundIntent(
          id: 'refund',
          originalSaleId: 'sale',
          scope: f.scope,
          shiftId: 'shift',
          ordinal: 4,
          occurredAt: f.now,
          lines: [
            RefundLine(
                productId: 'p',
                sku: 'MILK',
                name: 'Milk',
                unit: 'piece',
                factor: 1,
                priceCentavos: 1250,
                quantity: 1,
                refundCentavos: 1250)
          ],
          tenderKind: 'cash',
          reason: 'Return',
          authorizedByCashierId: 'c'));
    });
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen(scale: 2));
    await pumpCheckout(tester);
    await tester.tap(find.byTooltip('Shift'));
    await pumpCheckout(tester);
    expect(find.text('Debt repayment'), findsOneWidget);
    expect(find.text('Refund'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'opens shift, records cash reason and requires discrepancy reason at close',
      (tester) async {
    final f = CheckoutFixture();
    await tester.runAsync(() => f.create(shift: false));
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await tester.tap(find.text('Open shift'));
    await pumpCheckout(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Opening float'), '50.00');
    await tester.pump();
    await tester.tap(find.text('Save shift'));
    await pumpCheckout(tester);
    expect(find.text('Scan'), findsOneWidget);
    await tester.tap(find.byTooltip('Shift'));
    await pumpCheckout(tester);
    expect(find.text('Expected cash ₱50.00'), findsOneWidget);
    await tester.tap(find.text('Cash in'));
    await pumpCheckout(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '10.00');
    await tester.enterText(
        find.widgetWithText(TextField, 'Reason'), 'Added float');
    await tester.pump();
    await tester.tap(find.text('Save movement'));
    await pumpCheckout(tester);
    expect(find.text('Expected cash ₱60.00'), findsOneWidget);
    await tester.tap(find.text('Close shift'));
    await pumpCheckout(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Counted cash'), '59.00');
    await pumpCheckout(tester);
    expect(find.text('Difference -₱1.00'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save close'))
            .onPressed,
        isNull);
    await tester.enterText(
        find.widgetWithText(TextField, 'Reason'), 'Short cash');
    await pumpCheckout(tester);
    await tester.tap(find.text('Save close'));
    await pumpCheckout(tester);
    expect(
        await tester.runAsync(() => f.store.checkout.activeShift('d')), isNull);
  });
}
