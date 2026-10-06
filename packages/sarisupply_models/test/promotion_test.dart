import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  final line1 = CartLine(
    productId: 'p_coke',
    sku: 'COKE-1L',
    name: 'Coca Cola 1L',
    unit: 'bottle',
    factor: 1,
    priceCentavos: 5000, // PHP 50.00
    quantity: 3,
    catalogSequence: 1,
    catalogRevision: 1,
  );

  final line2 = CartLine(
    productId: 'p_chips',
    sku: 'CHIPS-50G',
    name: 'Potato Chips',
    unit: 'pack',
    factor: 1,
    priceCentavos: 2500, // PHP 25.00
    quantity: 4,
    catalogSequence: 1,
    catalogRevision: 1,
  );

  group('PromotionRule & PromotionEngine', () {
    test(
        'percentage discount calculates exact integer centavos with truncation',
        () {
      final rule = PromotionRule(
        id: 'promo_pct_10',
        name: '10% off Coke',
        type: PromotionType.percentage,
        targetProductId: 'p_coke',
        minimumQuantity: 1,
        discountValue: 1000, // 1000 basis points = 10%
      );

      // Line 1: 3 * 5000 = 15,000 centavos. 10% = 1,500 centavos.
      final result = PromotionEngine.evaluate(
        rules: [rule],
        lines: [line1, line2],
      );

      expect(result.lineDiscounts['p_coke'], 1500);
      expect(result.lineDiscounts['p_chips'], isNull);
      expect(result.totalDiscountCentavos, 1500);
    });

    test('fixed amount discount applies per minimum quantity bundle', () {
      final rule = PromotionRule(
        id: 'promo_fixed_500',
        name: 'PHP 5 off every 2 packs of chips',
        type: PromotionType.fixedAmount,
        targetProductId: 'p_chips',
        minimumQuantity: 2,
        discountValue: 500, // PHP 5.00 off per 2 packs
      );

      // Line 2: 4 packs. 4 ~/ 2 = 2 bundles. 2 * 500 = 1,000 centavos discount.
      final result = PromotionEngine.evaluate(
        rules: [rule],
        lines: [line2],
      );

      expect(result.lineDiscounts['p_chips'], 1000);
      expect(result.totalDiscountCentavos, 1000);
    });

    test('bundle pricing applies exact bundle delta', () {
      final rule = PromotionRule(
        id: 'promo_bundle_coke',
        name: 'Buy 3 Cokes for PHP 120 (regular 150)',
        type: PromotionType.bundle,
        targetProductId: 'p_coke',
        minimumQuantity: 3,
        discountValue: 12000, // Bundle price: PHP 120.00
      );

      // Line 1: 3 * 5000 = 15,000. Bundle price is 12,000. Discount = 3,000.
      final result = PromotionEngine.evaluate(
        rules: [rule],
        lines: [line1],
      );

      expect(result.lineDiscounts['p_coke'], 3000);
      expect(result.totalDiscountCentavos, 3000);
    });

    test('cart threshold discount applies when total reaches threshold', () {
      final rule = PromotionRule(
        id: 'promo_cart_thresh',
        name: 'Spend PHP 200, get PHP 20 off',
        type: PromotionType.cartThreshold,
        thresholdCentavos: 20000, // PHP 200.00
        discountValue: 2000, // PHP 20.00
      );

      // Cart total: 3 * 5000 + 4 * 2500 = 15,000 + 10,000 = 25,000 centavos (>= 20,000)
      final result = PromotionEngine.evaluate(
        rules: [rule],
        lines: [line1, line2],
      );

      expect(result.cartDiscountCentavos, 2000);
      expect(result.totalDiscountCentavos, 2000);
    });

    test('discounts never exceed line or cart total (zero negative price)', () {
      final extremeRule = PromotionRule(
        id: 'promo_extreme',
        name: 'Excessive discount',
        type: PromotionType.fixedAmount,
        targetProductId: 'p_coke',
        minimumQuantity: 1,
        discountValue: 100000, // 1,000 PHP off
      );

      final result = PromotionEngine.evaluate(
        rules: [extremeRule],
        lines: [line1],
      );

      // Total for 3 cokes is 15,000 centavos. Discount capped at 15,000!
      expect(result.lineDiscounts['p_coke'], 15000);
      expect(result.totalDiscountCentavos, 15000);
    });

    test('inactive rules are ignored', () {
      final rule = PromotionRule(
        id: 'promo_inactive',
        name: 'Expired 50% promo',
        type: PromotionType.percentage,
        targetProductId: 'p_coke',
        discountValue: 5000,
        active: false,
      );

      final result = PromotionEngine.evaluate(
        rules: [rule],
        lines: [line1],
      );

      expect(result.totalDiscountCentavos, 0);
    });
  });
}
