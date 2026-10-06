import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

final scope = CheckoutScope(
    merchantId: 'm',
    branchId: 'b',
    deviceId: 'd',
    cashierId: 'c',
    grantId: 'g',
    credentialVersion: 1);
CartLine line(
        {int quantity = 1,
        int price = 1250,
        int factor = 1,
        String productId = 'p'}) =>
    CartLine(
        productId: productId,
        sku: 'MILK',
        name: 'Milk',
        unit: 'piece',
        factor: factor,
        priceCentavos: price,
        quantity: quantity,
        catalogSequence: 1,
        catalogRevision: 1);
CheckoutSale sale(List<CartLine> lines, Tender tender) => CheckoutSale(
    id: 'sale',
    scope: scope,
    shiftId: 'shift',
    ordinal: 2,
    occurredAt: DateTime.utc(2026, 10, 5),
    merchantName: 'Store',
    branchName: 'Main',
    lines: lines,
    tender: tender);
void main() {
  test('receipt preserves the full approved 300-character merchant name', () {
    final s = CheckoutScope(
        merchantId: 'm',
        branchId: 'b',
        deviceId: 'd',
        cashierId: 'c',
        grantId: 'g',
        credentialVersion: 1);
    final receipt = CheckoutSale(
        id: 'sale',
        scope: s,
        shiftId: 'shift',
        ordinal: 2,
        occurredAt: DateTime.utc(2026),
        merchantName: 'A' * 300,
        branchName: 'B' * 300,
        lines: [
          CartLine(
              productId: 'p',
              sku: 'P',
              name: 'Item',
              unit: 'piece',
              factor: 1,
              priceCentavos: 1,
              quantity: 1,
              catalogSequence: 1,
              catalogRevision: 1)
        ],
        tender: const Tender.cash(1));
    expect(receipt.merchantName.length, 300);
  });

  test('negative PHP variance shows minus before currency', () {
    expect(formatPhp(-100), '-₱1.00');
  });
  test('pack conversion and centavo change are exact', () {
    final pack = line(quantity: 2, factor: 6);
    expect(pack.baseQuantity, 12);
    expect(sale([line()], Tender.cash(2000)).changeCentavos, 750);
  });
  test('QR needs explicit manual confirmation and reference', () {
    expect(() => sale([line()], Tender.qr('ref', confirmed: false)),
        throwsArgumentError);
    expect(() => sale([line()], Tender.qr('  ', confirmed: true)),
        throwsArgumentError);
    expect(sale([line()], Tender.qr('ref', confirmed: true)).changeCentavos, 0);
  });
  test('cash cannot be short and zero total cannot manufacture QR payment', () {
    expect(() => sale([line()], Tender.cash(1249)), throwsArgumentError);
    expect(sale([line(price: 0)], Tender.cash(0)).totalCentavos, 0);
    expect(() => sale([line(price: 0)], Tender.qr('ref', confirmed: true)),
        throwsArgumentError);
  });
  test('quantity, multiplication and receipt bounds reject overflow', () {
    expect(() => line(quantity: 0), throwsArgumentError);
    expect(
        () => line(quantity: 1000000000, factor: 1000000), throwsArgumentError);
    expect(
        () => sale(
            [line(quantity: 2, price: 1000000000)], Tender.cash(1000000000)),
        throwsArgumentError);
    expect(() => sale(List.generate(51, (_) => line()), Tender.cash(100000)),
        throwsArgumentError);
    expect(
        () => sale(List.generate(21, (i) => line(productId: 'p$i')),
            Tender.cash(100000)),
        throwsArgumentError);
  });
  test('inconsistent same-product quotes cannot enter one receipt', () {
    expect(() => sale([line(), line(price: 1300)], Tender.cash(10000)),
        throwsArgumentError);
  });
  test('receipt snapshots survive roundtrip and source list mutation', () {
    final source = [line()];
    final original = sale(source, Tender.cash(2000));
    source.clear();
    expect(original.lines, hasLength(1));
    final restored = CheckoutSale.fromMap(original.toMap());
    expect(restored.toMap(), original.toMap());
    expect(() => original.lines.clear(), throwsUnsupportedError);
  });
  test(
      'atomic stock event preserves legacy counts and rejects duplicate sale positions',
      () {
    final count = StockEvent.legacy(const StockChange(1, 'p', 10, 1, 'count'));
    expect(count.positions.single.quantity, 10);
    expect(count.positions.single.delta, isNull);
    final position = StockPosition('p', -1, 2, delta: -1);
    expect(
        () => StockEvent(
            sequence: 2,
            operationId: 'sale',
            kind: 'sale',
            positions: [position, position]),
        throwsArgumentError);
  });
  test(
      'cash parsing accepts decimals without floating point or extra precision',
      () {
    expect(parsePhpCentavos('12.50'), 1250);
    expect(parsePhpCentavos('0'), 0);
    expect(() => parsePhpCentavos('12.501'), throwsFormatException);
    expect(() => parsePhpCentavos('1e9'), throwsFormatException);
  });
}
