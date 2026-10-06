part of 'checkout.dart';

final class CartLine {
  CartLine(
      {required this.productId,
      required this.sku,
      required this.name,
      required this.unit,
      required this.factor,
      required this.priceCentavos,
      required this.quantity,
      required this.catalogSequence,
      required this.catalogRevision}) {
    checkoutId(productId);
    checkoutText(sku, 40);
    checkoutText(name, 120);
    checkoutText(unit, 30);
    checkoutAmount(priceCentavos);
    checkoutAmount(quantity, minimum: 1);
    if (factor < 1 ||
        factor > 1000000 ||
        quantity > checkoutLimit ~/ factor ||
        catalogSequence < 1 ||
        catalogRevision < 1 ||
        (priceCentavos > 0 && quantity > checkoutLimit ~/ priceCentavos)) {
      throw ArgumentError('Invalid quote or quantity');
    }
  }
  final String productId, sku, name, unit;
  final int factor, priceCentavos, quantity, catalogSequence, catalogRevision;
  int get baseQuantity => quantity * factor;
  int get totalCentavos => quantity * priceCentavos;
  CartLine withQuantity(int value) => CartLine(
      productId: productId,
      sku: sku,
      name: name,
      unit: unit,
      factor: factor,
      priceCentavos: priceCentavos,
      quantity: value,
      catalogSequence: catalogSequence,
      catalogRevision: catalogRevision);
  Map<String, Object?> toMap() => {
        'productId': productId,
        'sku': sku,
        'name': name,
        'unit': unit,
        'factor': factor,
        'priceCentavos': priceCentavos,
        'quantity': quantity,
        'catalogSequence': catalogSequence,
        'catalogRevision': catalogRevision
      };
  factory CartLine.fromMap(Map<String, Object?> m) => CartLine(
      productId: m['productId'] as String,
      sku: m['sku'] as String,
      name: m['name'] as String,
      unit: m['unit'] as String,
      factor: m['factor'] as int,
      priceCentavos: m['priceCentavos'] as int,
      quantity: m['quantity'] as int,
      catalogSequence: m['catalogSequence'] as int,
      catalogRevision: m['catalogRevision'] as int);
}

final class CheckoutSale {
  CheckoutSale(
      {required this.id,
      required this.scope,
      required this.shiftId,
      required this.ordinal,
      required this.occurredAt,
      required this.merchantName,
      required this.branchName,
      required List<CartLine> lines,
      required this.tender})
      : lines = List.unmodifiable(lines) {
    checkoutId(id);
    checkoutId(shiftId);
    checkoutText(merchantName, 300);
    checkoutText(branchName, 300);
    if (ordinal < 2 ||
        lines.isEmpty ||
        lines.length > 50 ||
        lines.map((l) => l.productId).toSet().length > 20) {
      throw ArgumentError('Invalid receipt');
    }
    var total = 0;
    final products = <String, CartLine>{};
    final units = <String, CartLine>{};
    final quantities = <String, int>{};
    for (final l in lines) {
      final p = products[l.productId];
      final u = units['${l.productId}\u0000${l.unit}'];
      if (p != null &&
          (p.sku != l.sku ||
              p.name != l.name ||
              p.catalogSequence != l.catalogSequence ||
              p.catalogRevision != l.catalogRevision)) {
        throw ArgumentError('Inconsistent product quote');
      }
      if (u != null &&
          (u.factor != l.factor || u.priceCentavos != l.priceCentavos)) {
        throw ArgumentError('Inconsistent unit quote');
      }
      products[l.productId] = l;
      units['${l.productId}\u0000${l.unit}'] = l;
      quantities[l.productId] = (quantities[l.productId] ?? 0) + l.baseQuantity;
      if (quantities[l.productId]! > checkoutLimit ||
          total > checkoutLimit - l.totalCentavos) {
        throw ArgumentError('Receipt is too large');
      }
      total += l.totalCentavos;
    }
    tender.validate(total);
  }
  final String id, shiftId, merchantName, branchName;
  final CheckoutScope scope;
  final int ordinal;
  final DateTime occurredAt;
  final List<CartLine> lines;
  final Tender tender;
  int get totalCentavos => lines.fold(0, (sum, l) => sum + l.totalCentavos);
  int get changeCentavos =>
      tender.kind == 'cash' ? tender.receivedCentavos - totalCentavos : 0;
  Map<String, int> get baseQuantities {
    final result = <String, int>{};
    for (final l in lines) {
      result[l.productId] = (result[l.productId] ?? 0) + l.baseQuantity;
    }
    return Map.unmodifiable(result);
  }

  CheckoutIntent get intent => CheckoutIntent(
          id: id,
          scope: scope,
          shiftId: shiftId,
          ordinal: ordinal,
          occurredAt: occurredAt,
          kind: 'sale',
          payload: {
            'merchantName': merchantName,
            'branchName': branchName,
            'lines': lines.map((l) => l.toMap()).toList(),
            'tender': tender.toMap()
          });
  Map<String, Object?> toMap() => {
        'id': id,
        'scope': scope.toMap(),
        'shiftId': shiftId,
        'ordinal': ordinal,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        ...intent.payload
      };
  factory CheckoutSale.fromMap(Map<String, Object?> m) => CheckoutSale(
      id: m['id'] as String,
      scope: CheckoutScope.fromMap(checkoutMap(m['scope'])),
      shiftId: m['shiftId'] as String,
      ordinal: m['ordinal'] as int,
      occurredAt: DateTime.parse(m['occurredAt'] as String),
      merchantName: m['merchantName'] as String,
      branchName: m['branchName'] as String,
      lines: (m['lines'] as List)
          .map((l) => CartLine.fromMap(checkoutMap(l)))
          .toList(),
      tender: Tender.fromMap(checkoutMap(m['tender'])));
  factory CheckoutSale.fromIntent(CheckoutIntent i) =>
      CheckoutSale.fromMap({...i.toMap(), ...i.payload});
}

final class CheckoutDraft {
  CheckoutDraft(
      {required this.scope,
      required this.shiftId,
      required List<CartLine> lines,
      this.received = '',
      this.qrReference = '',
      this.qrConfirmed = false,
      this.tenderKind = 'cash',
      this.paymentAttemptId = '',
      this.frozenSale})
      : lines = List.unmodifiable(lines) {
    checkoutId(shiftId);
    if (paymentAttemptId.isNotEmpty) checkoutId(paymentAttemptId);
    if (lines.length > 50 || !['cash', 'qr', 'credit'].contains(tenderKind)) {
      throw ArgumentError('Invalid draft');
    }
  }
  final CheckoutScope scope;
  final String shiftId, received, qrReference, tenderKind, paymentAttemptId;
  final bool qrConfirmed;
  final List<CartLine> lines;
  final CheckoutSale? frozenSale;
  int get totalCentavos => lines.fold(0, (sum, l) => sum + l.totalCentavos);
  CheckoutDraft copyWith(
          {CheckoutScope? scope,
          List<CartLine>? lines,
          String? received,
          String? qrReference,
          bool? qrConfirmed,
          String? tenderKind,
          String? paymentAttemptId,
          CheckoutSale? frozenSale}) =>
      CheckoutDraft(
          scope: scope ?? this.scope,
          shiftId: shiftId,
          lines: lines ?? this.lines,
          received: received ?? this.received,
          qrReference: qrReference ?? this.qrReference,
          qrConfirmed: qrConfirmed ?? this.qrConfirmed,
          tenderKind: tenderKind ?? this.tenderKind,
          paymentAttemptId: paymentAttemptId ?? this.paymentAttemptId,
          frozenSale: frozenSale ?? this.frozenSale);
  Map<String, Object?> toMap() => {
        'scope': scope.toMap(),
        'shiftId': shiftId,
        'lines': lines.map((l) => l.toMap()).toList(),
        'received': received,
        'qrReference': qrReference,
        'qrConfirmed': qrConfirmed,
        'tenderKind': tenderKind,
        'paymentAttemptId': paymentAttemptId,
        'frozenSale': frozenSale?.toMap()
      };
  factory CheckoutDraft.fromMap(Map<String, Object?> m) => CheckoutDraft(
      scope: CheckoutScope.fromMap(checkoutMap(m['scope'])),
      shiftId: m['shiftId'] as String,
      lines: (m['lines'] as List)
          .map((l) => CartLine.fromMap(checkoutMap(l)))
          .toList(),
      received: m['received'] as String,
      qrReference: m['qrReference'] as String,
      qrConfirmed: m['qrConfirmed'] as bool,
      tenderKind: m['tenderKind'] as String,
      paymentAttemptId: m['paymentAttemptId'] as String? ?? '',
      frozenSale: m['frozenSale'] == null
          ? null
          : CheckoutSale.fromMap(checkoutMap(m['frozenSale'])));
}
