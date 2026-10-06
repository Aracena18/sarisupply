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
    deviceId: 'd1',
    cashierId: 'c1',
    grantId: 'g1',
    credentialVersion: 1,
  );

  final sampleProduct = CatalogProduct(
    id: 'p1',
    sku: 'MILK',
    name: 'Fresh Milk',
    baseUnit: 'piece',
    revision: 1,
    active: true,
    units: [
      CatalogUnit(name: 'piece', factor: 1, priceCentavos: 5000),
    ],
  );

  late String path;

  setUp(() async {
    final dir =
        await Directory.systemTemp.createTemp('sarisupply_refund_test_');
    path = '${dir.path}/test.db';
  });

  tearDown(() async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  });

  Future<InventoryStore> openStore() async {
    final store = await InventoryStore.open(
      databaseFactoryFfi,
      path,
      merchantId: 'm1',
      branchId: 'b1',
    );
    await store.applyCatalog(DeltaPage(
      cursor: 1,
      hasMore: false,
      changes: [CatalogChange(1, sampleProduct)],
    ));
    await store.applyStock(DeltaPage(
      cursor: 1,
      hasMore: false,
      changes: [
        StockEvent(
          sequence: 1,
          operationId: 'op_init',
          kind: 'receiving',
          positions: [
            StockPosition('p1', 20, 1, delta: 20),
          ],
        ),
      ],
    ));
    return store;
  }

  test(
      'records refund atomically, updates stock, subtracts cash, and enforces ceilings',
      () async {
    final store = await openStore();
    final checkout = store.checkout;

    // 1. Open shift
    await checkout.openShift(CheckoutIntent(
      id: 'shift_1',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 1,
      occurredAt: DateTime.utc(2026, 10, 5, 8),
      kind: 'openShift',
      payload: {'floatCentavos': 10000},
    ));

    // 2. Complete sale: 5 pieces of milk for 25,000 centavos cash
    final cartLine = CartLine(
      productId: 'p1',
      sku: 'MILK',
      name: 'Fresh Milk',
      unit: 'piece',
      factor: 1,
      priceCentavos: 5000,
      quantity: 5,
      catalogSequence: 1,
      catalogRevision: 1,
    );

    final sale = CheckoutSale(
      id: 'sale_1',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 2,
      occurredAt: DateTime.utc(2026, 10, 5, 9),
      merchantName: 'Test Merchant',
      branchName: 'Test Branch',
      lines: [cartLine],
      tender: const Tender.cash(25000),
    );

    await checkout.saveDraft(CheckoutDraft(
      scope: scope,
      shiftId: 'shift_1',
      lines: [cartLine],
      frozenSale: sale,
    ));
    await checkout.completeSale(sale);

    // Initial stock was 20. Sold 5. Available = 15.
    var p = await store.getProduct('p1');
    expect(p?.quantity, 15);

    var shift = await checkout.activeShift('d1');
    expect(shift?.expectedCashCentavos, 35000); // 10000 float + 25000 cash

    // 3. Partial refund: 2 pieces (10,000 centavos)
    final refund = RefundIntent(
      id: 'ref_1',
      originalSaleId: 'sale_1',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 3,
      occurredAt: DateTime.utc(2026, 10, 5, 9, 30),
      lines: [
        RefundLine(
          productId: 'p1',
          sku: 'MILK',
          name: 'Fresh Milk',
          unit: 'piece',
          factor: 1,
          priceCentavos: 5000,
          quantity: 2,
          refundCentavos: 10000,
        ),
      ],
      tenderKind: 'cash',
      reason: 'Expired milk',
      authorizedByCashierId: 'c1',
    );

    await checkout.recordRefund(refund);

    // Stock restored by 2: 15 + 2 = 17.
    p = await store.getProduct('p1');
    expect(p?.quantity, 17);

    // Drawer cash subtracted by 10,000: 35000 - 10000 = 25000.
    shift = await checkout.activeShift('d1');
    expect(shift?.expectedCashCentavos, 25000);

    // Outbox has pending refund
    final op = await checkout.operation('ref_1');
    expect(op?.kind, 'refund');
    expect(op?.status, 'pending');

    // 4. Over-refund attempt: trying to refund 4 more pieces (total would be 2+4=6 > 5 purchased)
    final overRefund = RefundIntent(
      id: 'ref_2',
      originalSaleId: 'sale_1',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 4,
      occurredAt: DateTime.utc(2026, 10, 5, 9, 35),
      lines: [
        RefundLine(
          productId: 'p1',
          sku: 'MILK',
          name: 'Fresh Milk',
          unit: 'piece',
          factor: 1,
          priceCentavos: 5000,
          quantity: 4,
          refundCentavos: 20000,
        ),
      ],
      tenderKind: 'cash',
      reason: 'Customer return',
      authorizedByCashierId: 'c1',
    );

    await expectLater(
      checkout.recordRefund(overRefund),
      throwsA(isA<ArgumentError>()),
    );

    // 5. Replay of same refund is idempotent
    await checkout.recordRefund(refund);
    p = await store.getProduct('p1');
    expect(p?.quantity, 17);

    await store.close();
  });

  test('voidSale restores all items, reverses tender, and marks sale voided',
      () async {
    final store = await openStore();
    final checkout = store.checkout;

    await checkout.openShift(CheckoutIntent(
      id: 'shift_1',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 1,
      occurredAt: DateTime.utc(2026, 10, 5, 8),
      kind: 'openShift',
      payload: {'floatCentavos': 5000},
    ));

    final cartLine = CartLine(
      productId: 'p1',
      sku: 'MILK',
      name: 'Fresh Milk',
      unit: 'piece',
      factor: 1,
      priceCentavos: 5000,
      quantity: 3,
      catalogSequence: 1,
      catalogRevision: 1,
    );

    final sale = CheckoutSale(
      id: 'sale_void',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 2,
      occurredAt: DateTime.utc(2026, 10, 5, 9),
      merchantName: 'Test Merchant',
      branchName: 'Test Branch',
      lines: [cartLine],
      tender: const Tender.cash(15000),
    );

    await checkout.saveDraft(CheckoutDraft(
      scope: scope,
      shiftId: 'shift_1',
      lines: [cartLine],
      frozenSale: sale,
    ));
    await checkout.completeSale(sale);

    var p = await store.getProduct('p1');
    expect(p?.quantity, 17);

    // Void the sale
    final voidIntent = VoidIntent(
      id: 'void_1',
      originalSaleId: 'sale_void',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 3,
      occurredAt: DateTime.utc(2026, 10, 5, 9, 15),
      reason: 'Wrong customer transaction',
      authorizedByCashierId: 'c1',
      voidCentavos: 15000,
      tenderKind: 'cash',
    );

    await checkout.voidSale(voidIntent);

    // Quantity restored fully to 20
    p = await store.getProduct('p1');
    expect(p?.quantity, 20);

    // Drawer cash reverted to 5000
    final shift = await checkout.activeShift('d1');
    expect(shift?.expectedCashCentavos, 5000);

    // Attempting to refund voided sale fails
    final refund = RefundIntent(
      id: 'ref_after_void',
      originalSaleId: 'sale_void',
      scope: scope,
      shiftId: 'shift_1',
      ordinal: 4,
      occurredAt: DateTime.utc(2026, 10, 5, 9, 20),
      lines: [
        RefundLine(
          productId: 'p1',
          sku: 'MILK',
          name: 'Fresh Milk',
          unit: 'piece',
          factor: 1,
          priceCentavos: 5000,
          quantity: 1,
          refundCentavos: 5000,
        ),
      ],
      tenderKind: 'cash',
      reason: 'Return',
      authorizedByCashierId: 'c1',
    );

    await expectLater(
      checkout.recordRefund(refund),
      throwsA(isA<StateError>()),
    );

    await store.close();
  });
}
