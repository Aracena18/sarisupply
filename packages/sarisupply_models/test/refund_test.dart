import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  final scope = CheckoutScope(
    merchantId: 'm1',
    branchId: 'b1',
    deviceId: 'd1',
    cashierId: 'c1',
    grantId: 'g1',
    credentialVersion: 1,
  );

  final sampleLine = RefundLine(
    productId: 'prod1',
    sku: 'SKU1',
    name: 'Item 1',
    unit: 'piece',
    factor: 1,
    priceCentavos: 1000,
    quantity: 2,
    refundCentavos: 2000,
  );

  group('RefundLine', () {
    test('validates attributes and calculates baseQuantity', () {
      expect(sampleLine.productId, 'prod1');
      expect(sampleLine.baseQuantity, 2);
      expect(sampleLine.refundCentavos, 2000);

      final packLine = RefundLine(
        productId: 'prod2',
        sku: 'SKU2',
        name: 'Pack of 6',
        unit: 'pack',
        factor: 6,
        priceCentavos: 5000,
        quantity: 3,
        refundCentavos: 15000,
      );
      expect(packLine.baseQuantity, 18);
    });

    test('rejects refundCentavos exceeding quantity * priceCentavos', () {
      expect(
        () => RefundLine(
          productId: 'prod1',
          sku: 'SKU1',
          name: 'Item 1',
          unit: 'piece',
          factor: 1,
          priceCentavos: 1000,
          quantity: 2,
          refundCentavos: 2001,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative refundCentavos or zero quantity', () {
      expect(
        () => RefundLine(
          productId: 'prod1',
          sku: 'SKU1',
          name: 'Item 1',
          unit: 'piece',
          factor: 1,
          priceCentavos: 1000,
          quantity: 0,
          refundCentavos: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => RefundLine(
          productId: 'prod1',
          sku: 'SKU1',
          name: 'Item 1',
          unit: 'piece',
          factor: 1,
          priceCentavos: 1000,
          quantity: 1,
          refundCentavos: -1,
        ),
        throwsArgumentError,
      );
    });

    test('serialization roundtrip preserves all fields', () {
      final map = sampleLine.toMap();
      final roundtrip = RefundLine.fromMap(map);
      expect(roundtrip.productId, sampleLine.productId);
      expect(roundtrip.sku, sampleLine.sku);
      expect(roundtrip.name, sampleLine.name);
      expect(roundtrip.unit, sampleLine.unit);
      expect(roundtrip.factor, sampleLine.factor);
      expect(roundtrip.priceCentavos, sampleLine.priceCentavos);
      expect(roundtrip.quantity, sampleLine.quantity);
      expect(roundtrip.refundCentavos, sampleLine.refundCentavos);
    });
  });

  group('RefundIntent', () {
    test('calculates totalRefundCentavos and baseQuantities accurately', () {
      final refund = RefundIntent(
        id: 'ref1',
        originalSaleId: 'sale1',
        scope: scope,
        shiftId: 'shift1',
        ordinal: 2,
        occurredAt: DateTime.utc(2026, 10, 5, 10),
        lines: [
          sampleLine,
          RefundLine(
            productId: 'prod1',
            sku: 'SKU1',
            name: 'Item 1',
            unit: 'pack',
            factor: 10,
            priceCentavos: 9000,
            quantity: 1,
            refundCentavos: 9000,
          ),
        ],
        tenderKind: 'cash',
        reason: 'Customer return - defective',
        authorizedByCashierId: 'c1',
      );

      expect(refund.totalRefundCentavos, 11000);
      expect(refund.baseQuantities['prod1'], 12); // 2*1 + 1*10
      expect(refund.lines, isA<List>());

      final intent = refund.toCheckoutIntent();
      expect(intent.kind, 'refund');
      expect(intent.id, 'ref1');
    });

    test('rejects empty lines or invalid tender', () {
      expect(
        () => RefundIntent(
          id: 'ref1',
          originalSaleId: 'sale1',
          scope: scope,
          shiftId: 'shift1',
          ordinal: 2,
          occurredAt: DateTime.utc(2026, 10, 5, 10),
          lines: [],
          tenderKind: 'cash',
          reason: 'Defective',
          authorizedByCashierId: 'c1',
        ),
        throwsArgumentError,
      );

      expect(
        () => RefundIntent(
          id: 'ref1',
          originalSaleId: 'sale1',
          scope: scope,
          shiftId: 'shift1',
          ordinal: 2,
          occurredAt: DateTime.utc(2026, 10, 5, 10),
          lines: [sampleLine],
          tenderKind: 'bitcoin',
          reason: 'Defective',
          authorizedByCashierId: 'c1',
        ),
        throwsArgumentError,
      );
    });

    test('serialization roundtrip preserves all fields', () {
      final refund = RefundIntent(
        id: 'ref1',
        originalSaleId: 'sale1',
        scope: scope,
        shiftId: 'shift1',
        ordinal: 2,
        occurredAt: DateTime.utc(2026, 10, 5, 10),
        lines: [sampleLine],
        tenderKind: 'cash',
        reason: 'Defective',
        authorizedByCashierId: 'c1',
      );

      final map = refund.toMap();
      final roundtrip = RefundIntent.fromMap(map);
      expect(roundtrip.id, refund.id);
      expect(roundtrip.originalSaleId, refund.originalSaleId);
      expect(roundtrip.shiftId, refund.shiftId);
      expect(roundtrip.totalRefundCentavos, refund.totalRefundCentavos);
      expect(roundtrip.reason, refund.reason);
      expect(roundtrip.lines.single.productId, 'prod1');
    });
  });

  group('VoidIntent', () {
    test('creates and serializes void intent', () {
      final voidIntent = VoidIntent(
        id: 'void1',
        originalSaleId: 'sale1',
        scope: scope,
        shiftId: 'shift1',
        ordinal: 2,
        occurredAt: DateTime.utc(2026, 10, 5, 10),
        reason: 'Accidental double entry',
        authorizedByCashierId: 'c1',
        voidCentavos: 5000,
        tenderKind: 'cash',
      );

      expect(voidIntent.id, 'void1');
      expect(voidIntent.voidCentavos, 5000);
      expect(voidIntent.tenderKind, 'cash');

      final intent = voidIntent.toCheckoutIntent();
      expect(intent.kind, 'voidSale');

      final roundtrip = VoidIntent.fromMap(voidIntent.toMap());
      expect(roundtrip.id, voidIntent.id);
      expect(roundtrip.originalSaleId, voidIntent.originalSaleId);
      expect(roundtrip.voidCentavos, voidIntent.voidCentavos);
      expect(roundtrip.reason, voidIntent.reason);
    });

    test('rejects negative voidCentavos or invalid ordinal', () {
      expect(
        () => VoidIntent(
          id: 'void1',
          originalSaleId: 'sale1',
          scope: scope,
          shiftId: 'shift1',
          ordinal: 1, // must be > 1 since 1 is openShift
          occurredAt: DateTime.utc(2026, 10, 5, 10),
          reason: 'Accidental entry',
          authorizedByCashierId: 'c1',
          voidCentavos: 5000,
        ),
        throwsArgumentError,
      );

      expect(
        () => VoidIntent(
          id: 'void1',
          originalSaleId: 'sale1',
          scope: scope,
          shiftId: 'shift1',
          ordinal: 2,
          occurredAt: DateTime.utc(2026, 10, 5, 10),
          reason: 'Accidental entry',
          authorizedByCashierId: 'c1',
          voidCentavos: -100,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Shift integration with Refund and Void', () {
    test('CashierShift apply refund and void updates cash balance correctly',
        () {
      var shift = CashierShift(
        id: 'shift1',
        scope: scope,
        openingFloatCentavos: 5000,
      );
      expect(shift.expectedCashCentavos, 5000);

      // Sale adds cash
      final saleIntent = CheckoutIntent(
        id: 'sale1',
        scope: scope,
        shiftId: 'shift1',
        ordinal: 2,
        occurredAt: DateTime.utc(2026, 10, 5, 10),
        kind: 'sale',
        payload: {
          'id': 'sale1',
          'shiftId': 'shift1',
          'ordinal': 2,
          'occurredAt': DateTime.utc(2026, 10, 5, 10).toIso8601String(),
          'merchantName': 'Test Merchant',
          'branchName': 'Test Branch',
          'scope': scope.toMap(),
          'lines': [
            CartLine(
              productId: 'prod1',
              sku: 'SKU1',
              name: 'Item 1',
              unit: 'piece',
              factor: 1,
              priceCentavos: 1000,
              quantity: 2,
              catalogSequence: 1,
              catalogRevision: 1,
            ).toMap()
          ],
          'tender': const Tender.cash(2000).toMap(),
        },
      );
      shift = shift.apply(saleIntent);
      expect(shift.expectedCashCentavos, 7000);

      // Refund subtracts cash
      final refund = RefundIntent(
        id: 'ref1',
        originalSaleId: 'sale1',
        scope: scope,
        shiftId: 'shift1',
        ordinal: 3,
        occurredAt: DateTime.utc(2026, 10, 5, 10, 5),
        lines: [
          RefundLine(
            productId: 'prod1',
            sku: 'SKU1',
            name: 'Item 1',
            unit: 'piece',
            factor: 1,
            priceCentavos: 1000,
            quantity: 1,
            refundCentavos: 1000,
          ),
        ],
        tenderKind: 'cash',
        reason: 'Customer return',
        authorizedByCashierId: 'c1',
      );

      shift = shift.apply(refund.toCheckoutIntent());
      expect(shift.expectedCashCentavos, 6000);
      expect(shift.cashRefundCentavos, 1000);

      // Void subtracts cash
      final voidIntent = VoidIntent(
        id: 'void1',
        originalSaleId: 'sale1',
        scope: scope,
        shiftId: 'shift1',
        ordinal: 4,
        occurredAt: DateTime.utc(2026, 10, 5, 10, 10),
        reason: 'Sale voided',
        authorizedByCashierId: 'c1',
        voidCentavos: 1000,
        tenderKind: 'cash',
      );

      shift = shift.apply(voidIntent.toCheckoutIntent());
      expect(shift.expectedCashCentavos, 5000);
      expect(shift.cashRefundCentavos, 2000);
    });
  });
}
