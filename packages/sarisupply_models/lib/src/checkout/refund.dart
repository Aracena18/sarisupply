part of 'checkout.dart';

final class RefundLine {
  RefundLine({
    required this.productId,
    required this.sku,
    required this.name,
    required this.unit,
    required this.factor,
    required this.priceCentavos,
    required this.quantity,
    required this.refundCentavos,
  }) {
    checkoutId(productId);
    checkoutText(sku, 40);
    checkoutText(name, 120);
    checkoutText(unit, 30);
    checkoutAmount(priceCentavos);
    checkoutAmount(quantity, minimum: 1);
    checkoutAmount(refundCentavos, minimum: 0);
    if (factor < 1 ||
        factor > 1000000 ||
        quantity > checkoutLimit ~/ factor ||
        (priceCentavos > 0 && quantity > checkoutLimit ~/ priceCentavos) ||
        refundCentavos > quantity * priceCentavos) {
      throw ArgumentError('Invalid refund line');
    }
  }

  final String productId, sku, name, unit;
  final int factor, priceCentavos, quantity, refundCentavos;

  int get baseQuantity => quantity * factor;

  Map<String, Object?> toMap() => {
        'productId': productId,
        'sku': sku,
        'name': name,
        'unit': unit,
        'factor': factor,
        'priceCentavos': priceCentavos,
        'quantity': quantity,
        'refundCentavos': refundCentavos,
      };

  factory RefundLine.fromMap(Map<String, Object?> m) => RefundLine(
        productId: m['productId'] as String,
        sku: m['sku'] as String,
        name: m['name'] as String,
        unit: m['unit'] as String,
        factor: m['factor'] as int,
        priceCentavos: m['priceCentavos'] as int,
        quantity: m['quantity'] as int,
        refundCentavos: m['refundCentavos'] as int,
      );
}

final class RefundIntent {
  RefundIntent({
    required this.id,
    required this.originalSaleId,
    required this.scope,
    required this.shiftId,
    required this.ordinal,
    required this.occurredAt,
    required List<RefundLine> lines,
    required this.tenderKind,
    required this.reason,
    required this.authorizedByCashierId,
  }) : lines = List.unmodifiable(lines) {
    checkoutId(id);
    checkoutId(originalSaleId);
    checkoutId(shiftId);
    checkoutId(authorizedByCashierId);
    checkoutText(reason, 160);
    if (ordinal < 2 || lines.isEmpty || lines.length > 50) {
      throw ArgumentError('Invalid refund intent');
    }
    if (!['cash', 'qr', 'credit'].contains(tenderKind)) {
      throw ArgumentError('Invalid tender kind for refund');
    }
    var total = 0;
    for (final l in lines) {
      if (total > checkoutLimit - l.refundCentavos) {
        throw ArgumentError('Refund is too large');
      }
      total += l.refundCentavos;
    }
  }

  final String id,
      originalSaleId,
      shiftId,
      tenderKind,
      reason,
      authorizedByCashierId;
  final CheckoutScope scope;
  final int ordinal;
  final DateTime occurredAt;
  final List<RefundLine> lines;

  int get totalRefundCentavos =>
      lines.fold(0, (sum, l) => sum + l.refundCentavos);

  Map<String, int> get baseQuantities {
    final map = <String, int>{};
    for (final l in lines) {
      map[l.productId] = (map[l.productId] ?? 0) + l.baseQuantity;
    }
    return Map.unmodifiable(map);
  }

  CheckoutIntent toCheckoutIntent() => CheckoutIntent(
        id: id,
        scope: scope,
        shiftId: shiftId,
        ordinal: ordinal,
        occurredAt: occurredAt,
        kind: 'refund',
        payload: toMap(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'originalSaleId': originalSaleId,
        'scope': scope.toMap(),
        'shiftId': shiftId,
        'ordinal': ordinal,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'lines': lines.map((l) => l.toMap()).toList(),
        'tenderKind': tenderKind,
        'reason': reason,
        'authorizedByCashierId': authorizedByCashierId,
        'totalRefundCentavos': totalRefundCentavos,
      };

  factory RefundIntent.fromMap(Map<String, Object?> m) => RefundIntent(
        id: m['id'] as String,
        originalSaleId: m['originalSaleId'] as String,
        scope: CheckoutScope.fromMap(checkoutMap(m['scope'])),
        shiftId: m['shiftId'] as String,
        ordinal: m['ordinal'] as int,
        occurredAt: DateTime.parse(m['occurredAt'] as String),
        lines: (m['lines'] as List)
            .map((e) => RefundLine.fromMap(checkoutMap(e)))
            .toList(),
        tenderKind: m['tenderKind'] as String,
        reason: m['reason'] as String,
        authorizedByCashierId: m['authorizedByCashierId'] as String,
      );
}

final class VoidIntent {
  VoidIntent({
    required this.id,
    required this.originalSaleId,
    required this.scope,
    required this.shiftId,
    required this.ordinal,
    required this.occurredAt,
    required this.reason,
    required this.authorizedByCashierId,
    required this.voidCentavos,
    this.tenderKind = 'cash',
  }) {
    checkoutId(id);
    checkoutId(originalSaleId);
    checkoutId(shiftId);
    checkoutId(authorizedByCashierId);
    checkoutText(reason, 160);
    checkoutAmount(voidCentavos);
    if (ordinal < 2) {
      throw ArgumentError('Invalid void intent ordinal');
    }
    if (!['cash', 'qr', 'credit'].contains(tenderKind)) {
      throw ArgumentError('Invalid tender kind for void');
    }
  }

  final String id,
      originalSaleId,
      shiftId,
      reason,
      authorizedByCashierId,
      tenderKind;
  final CheckoutScope scope;
  final int ordinal;
  final DateTime occurredAt;
  final int voidCentavos;

  CheckoutIntent toCheckoutIntent() => CheckoutIntent(
        id: id,
        scope: scope,
        shiftId: shiftId,
        ordinal: ordinal,
        occurredAt: occurredAt,
        kind: 'voidSale',
        payload: toMap(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'originalSaleId': originalSaleId,
        'scope': scope.toMap(),
        'shiftId': shiftId,
        'ordinal': ordinal,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'reason': reason,
        'authorizedByCashierId': authorizedByCashierId,
        'voidCentavos': voidCentavos,
        'tenderKind': tenderKind,
      };

  factory VoidIntent.fromMap(Map<String, Object?> m) => VoidIntent(
        id: m['id'] as String,
        originalSaleId: m['originalSaleId'] as String,
        scope: CheckoutScope.fromMap(checkoutMap(m['scope'])),
        shiftId: m['shiftId'] as String,
        ordinal: m['ordinal'] as int,
        occurredAt: DateTime.parse(m['occurredAt'] as String),
        reason: m['reason'] as String,
        authorizedByCashierId: m['authorizedByCashierId'] as String,
        voidCentavos: m['voidCentavos'] as int,
        tenderKind: (m['tenderKind'] as String?) ?? 'cash',
      );
}
