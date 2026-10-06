import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  final scope = CheckoutScope(
    merchantId: 'm1',
    branchId: 'b1',
    deviceId: 'dev1',
    cashierId: 'c1',
    grantId: 'g1',
    credentialVersion: 1,
  );

  final sampleProduct = CatalogProduct(
    id: 'p_rice',
    sku: 'RICE',
    name: 'Rice 1kg',
    baseUnit: 'kg',
    revision: 1,
    active: true,
    units: [
      CatalogUnit(name: 'kg', factor: 1, priceCentavos: 5000),
    ],
  );

  final cartLine = CartLine(
    productId: 'p_rice',
    sku: 'RICE',
    name: 'Rice 1kg',
    unit: 'kg',
    factor: 1,
    priceCentavos: 5000,
    quantity: 2, // Total 10,000 centavos
    catalogSequence: 1,
    catalogRevision: 1,
  );

  late String path;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('sarisupply_cust_test_');
    path = '${dir.path}/test.db';
  });

  tearDown(() async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test(
      'customers, credit sales, and debt repayments are locally durable and enforce limits',
      () async {
    final inventory = await InventoryStore.open(
      databaseFactoryFfi,
      path,
      merchantId: 'm1',
      branchId: 'b1',
    );
    await inventory.applyCatalog(DeltaPage(
      cursor: 1,
      hasMore: false,
      changes: [CatalogChange(1, sampleProduct)],
    ));
    await inventory.applyStock(DeltaPage(
      cursor: 1,
      hasMore: false,
      changes: [
        StockEvent(
          sequence: 1,
          operationId: 'op_stock',
          kind: 'receiving',
          positions: [StockPosition('p_rice', 100, 1, delta: 100)],
        )
      ],
    ));

    final checkout = inventory.checkout;

    // 1. Create a customer
    final customer = CustomerAccount(
      id: 'cust_1',
      name: 'Nanay Rosa',
      phone: '09170000001',
      creditLimitCentavos: 30000, // PHP 300.00
      balanceCentavos: 5000, // PHP 50.00 initial debt
    );
    await checkout.saveCustomer(customer);

    final fetched = await checkout.getCustomer('cust_1');
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Nanay Rosa');
    expect(fetched.availableCreditCentavos, 25000);

    // 2. Open shift
    final now = DateTime.utc(2026, 10, 5, 8, 0, 0);
    await checkout.openShift(CheckoutIntent(
      id: 'shift_1',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 1,
      occurredAt: now,
      kind: 'openShift',
      payload: {'floatCentavos': 10000},
    ));

    // 3. Complete sale on credit (10,000 centavos)
    final creditSale = CheckoutSale(
      id: 'sale_credit_1',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 2,
      occurredAt: now,
      merchantName: 'Store',
      branchName: 'Main',
      lines: [cartLine],
      tender: const Tender.credit('cust_1', creditGrantId: 'allowance_1'),
    );

    // Save draft first as required by checkout store
    await checkout.saveDraft(CheckoutDraft(
      scope: scope,
      shiftId: 'shift_1',
      lines: [cartLine],
      frozenSale: creditSale,
    ));

    final allowance = CreditAllowanceGrant(
        id: 'allowance_1',
        customerId: 'cust_1',
        deviceId: 'dev1',
        allowedCreditCentavos: 10000,
        expiresAt: now.add(const Duration(days: 7)));
    // A local allowance cannot authorize a financial operation.
    await checkout.saveCreditGrant(allowance);
    await expectLater(checkout.completeSale(creditSale), throwsStateError);
    expect((await checkout.getCustomer('cust_1'))!.balanceCentavos, 5000);
    await checkout.saveCreditGrant(allowance, serverIssued: true);
    await checkout.completeSale(creditSale);

    // Balance updated: 5,000 + 10,000 = 15,000
    final afterSaleCust = await checkout.getCustomer('cust_1');
    expect(afterSaleCust!.balanceCentavos, 15000);
    expect(afterSaleCust.availableCreditCentavos, 15000);

    // 4. Repay 8,000 in cash
    final repayment = DebtRepayment(
      id: 'rep_1',
      customerId: 'cust_1',
      amountCentavos: 8000,
      tenderKind: 'cash',
      occurredAt: now.add(const Duration(hours: 1)),
      shiftId: 'shift_1',
      cashierId: 'c1',
      notes: 'Partial payment',
    );
    await checkout.recordDebtRepayment(repayment);

    // Customer balance updated: 15,000 - 8,000 = 7,000
    final afterRepayCust = await checkout.getCustomer('cust_1');
    expect(afterRepayCust!.balanceCentavos, 7000);
    expect(afterRepayCust.availableCreditCentavos, 23000);

    // Cash shift updated: float 10,000 + repayment 8,000 = 18,000
    final shift = await checkout.activeShift('dev1');
    expect(shift!.expectedCashCentavos, 18000);
    expect(shift.cashInCentavos, 8000);

    final queued = await checkout.pendingIntents();
    expect(queued.map((intent) => intent.ordinal), [1, 2, 3]);
    expect(queued.last.kind, 'debtRepayment');
    await checkout.recordDebtRepayment(repayment);
    expect((await checkout.pendingIntents()).length, 3);
    expect((await checkout.getCustomer('cust_1'))!.balanceCentavos, 7000);

    // Repayment history accessible
    final repayments = await checkout.getDebtRepayments('cust_1');
    expect(repayments.length, 1);
    expect(repayments.first.amountCentavos, 8000);

    final refund = RefundIntent(
        id: 'credit_return',
        originalSaleId: creditSale.id,
        scope: scope,
        shiftId: 'shift_1',
        ordinal: 4,
        occurredAt: now.add(const Duration(hours: 2)),
        lines: [
          RefundLine(
              productId: cartLine.productId,
              sku: cartLine.sku,
              name: cartLine.name,
              unit: cartLine.unit,
              factor: cartLine.factor,
              priceCentavos: cartLine.priceCentavos,
              quantity: 1,
              refundCentavos: 5000)
        ],
        tenderKind: 'credit',
        reason: 'Return',
        authorizedByCashierId: 'c1');
    await checkout.recordRefund(refund);
    await checkout.recordRefund(refund);
    expect((await checkout.getCustomer('cust_1'))!.balanceCentavos, 2000);
    expect((await checkout.activeShift('dev1'))!.expectedCashCentavos, 18000);
    expect(
        (await checkout.getCreditGrant('cust_1', 'dev1'))!.usedCreditCentavos,
        10000);
    final repaidReturn = RefundIntent(
        id: 'repaid_return',
        originalSaleId: creditSale.id,
        scope: scope,
        shiftId: 'shift_1',
        ordinal: 5,
        occurredAt: now.add(const Duration(hours: 3)),
        lines: refund.lines,
        tenderKind: 'credit',
        reason: 'Return',
        authorizedByCashierId: 'c1');
    await expectLater(checkout.recordRefund(repaidReturn), throwsStateError);
    expect(await checkout.operation('repaid_return'), isNull);
    expect((await checkout.getCustomer('cust_1'))!.balanceCentavos, 2000);
    await inventory.close();
  });
}
