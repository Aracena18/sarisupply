import 'dart:math' as math;
import 'checkout.dart';

enum PromotionType {
  percentage,
  fixedAmount,
  bundle,
  cartThreshold,
}

final class PromotionRule {
  PromotionRule({
    required this.id,
    required this.name,
    required this.type,
    this.targetProductId,
    this.minimumQuantity = 1,
    this.thresholdCentavos = 0,
    required this.discountValue,
    this.active = true,
  }) {
    if (id.trim().isEmpty || id.length > 128 || id.contains('/')) {
      throw ArgumentError('Invalid promotion rule ID');
    }
    if (name.trim().isEmpty || name.length > 120) {
      throw ArgumentError('Invalid promotion name');
    }
    if (minimumQuantity < 1) {
      throw ArgumentError('Minimum quantity must be at least 1');
    }
    if (thresholdCentavos < 0) {
      throw ArgumentError('Threshold cannot be negative');
    }
    if (discountValue < 0) {
      throw ArgumentError('Discount value cannot be negative');
    }
    if (type == PromotionType.percentage && discountValue > 10000) {
      throw ArgumentError('Percentage cannot exceed 100% (10000 basis points)');
    }
  }

  final String id;
  final String name;
  final PromotionType type;
  final String? targetProductId;
  final int minimumQuantity;
  final int thresholdCentavos;
  final int discountValue;
  final bool active;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        if (targetProductId != null) 'targetProductId': targetProductId,
        'minimumQuantity': minimumQuantity,
        'thresholdCentavos': thresholdCentavos,
        'discountValue': discountValue,
        'active': active,
      };

  factory PromotionRule.fromMap(Map<String, Object?> map) => PromotionRule(
        id: map['id'] as String,
        name: map['name'] as String,
        type: PromotionType.values.byName(map['type'] as String),
        targetProductId: map['targetProductId'] as String?,
        minimumQuantity: map['minimumQuantity'] as int? ?? 1,
        thresholdCentavos: map['thresholdCentavos'] as int? ?? 0,
        discountValue: map['discountValue'] as int,
        active: map['active'] as bool? ?? true,
      );
}

final class PromotionResult {
  const PromotionResult({
    required this.lineDiscounts,
    required this.cartDiscountCentavos,
    required this.totalDiscountCentavos,
  });

  final Map<String, int> lineDiscounts;
  final int cartDiscountCentavos;
  final int totalDiscountCentavos;
}

final class PromotionEngine {
  static PromotionResult evaluate({
    required List<PromotionRule> rules,
    required List<CartLine> lines,
  }) {
    final activeRules = rules.where((r) => r.active).toList();
    final lineDiscounts = <String, int>{};
    var cartDiscountCentavos = 0;

    final cartSubtotal = lines.fold<int>(0, (sum, l) => sum + l.totalCentavos);

    for (final line in lines) {
      var lineDiscount = 0;
      for (final rule in activeRules) {
        if (rule.targetProductId != null &&
            rule.targetProductId != line.productId) {
          continue;
        }

        switch (rule.type) {
          case PromotionType.percentage:
            if (line.quantity >= rule.minimumQuantity) {
              final discount =
                  (line.totalCentavos * rule.discountValue) ~/ 10000;
              lineDiscount += discount;
            }
          case PromotionType.fixedAmount:
            if (line.quantity >= rule.minimumQuantity) {
              final bundles = line.quantity ~/ rule.minimumQuantity;
              lineDiscount += bundles * rule.discountValue;
            }
          case PromotionType.bundle:
            if (line.quantity >= rule.minimumQuantity) {
              final normalPrice = rule.minimumQuantity * line.priceCentavos;
              if (normalPrice > rule.discountValue) {
                final bundleSavings = normalPrice - rule.discountValue;
                final bundles = line.quantity ~/ rule.minimumQuantity;
                lineDiscount += bundles * bundleSavings;
              }
            }
          case PromotionType.cartThreshold:
            break;
        }
      }

      final cappedLineDiscount = math.min(lineDiscount, line.totalCentavos);
      if (cappedLineDiscount > 0) {
        lineDiscounts[line.productId] = cappedLineDiscount;
      }
    }

    for (final rule in activeRules) {
      if (rule.type == PromotionType.cartThreshold) {
        if (cartSubtotal >= rule.thresholdCentavos) {
          cartDiscountCentavos += rule.discountValue;
        }
      }
    }

    final totalLineDiscounts =
        lineDiscounts.values.fold<int>(0, (sum, d) => sum + d);
    final remainingAfterLine = math.max(0, cartSubtotal - totalLineDiscounts);
    final cappedCartDiscount =
        math.min(cartDiscountCentavos, remainingAfterLine);

    final totalDiscount = totalLineDiscounts + cappedCartDiscount;

    return PromotionResult(
      lineDiscounts: Map.unmodifiable(lineDiscounts),
      cartDiscountCentavos: cappedCartDiscount,
      totalDiscountCentavos: totalDiscount,
    );
  }
}
