part of 'checkout.dart';

final class CashierShift {
  CashierShift(
      {required this.id,
      required this.scope,
      required this.openingFloatCentavos,
      this.cashSalesCentavos = 0,
      this.cashInCentavos = 0,
      this.cashOutCentavos = 0,
      this.cashRefundCentavos = 0,
      this.lastOrdinal = 1,
      this.countedCentavos,
      this.reason = ''}) {
    checkoutId(id);
    checkoutAmount(openingFloatCentavos);
    for (final amount in [
      cashSalesCentavos,
      cashInCentavos,
      cashOutCentavos,
      cashRefundCentavos
    ]) {
      if (amount < 0 || amount > 9007199254740991) {
        throw ArgumentError('Shift amount overflow');
      }
    }
    if (expectedCashCentavos.abs() > 9007199254740991) {
      throw ArgumentError('Shift amount overflow');
    }
    if (countedCentavos != null) {
      checkoutAmount(countedCentavos!);
      if (varianceCentavos != 0) checkoutText(reason, 160);
    }
  }
  final String id, reason;
  final CheckoutScope scope;
  final int openingFloatCentavos,
      cashSalesCentavos,
      cashInCentavos,
      cashOutCentavos,
      cashRefundCentavos,
      lastOrdinal;
  final int? countedCentavos;
  bool get closed => countedCentavos != null;
  int get expectedCashCentavos =>
      openingFloatCentavos +
      cashSalesCentavos +
      cashInCentavos -
      cashOutCentavos -
      cashRefundCentavos;
  int? get varianceCentavos =>
      countedCentavos == null ? null : countedCentavos! - expectedCashCentavos;
  CashierShift apply(CheckoutIntent i) {
    if (closed ||
        i.shiftId != id ||
        !scope.sameCashier(i.scope) ||
        i.ordinal != lastOrdinal + 1) {
      throw StateError('Shift is closed or changed');
    }
    var sales = cashSalesCentavos,
        inside = cashInCentavos,
        outside = cashOutCentavos,
        refunds = cashRefundCentavos;
    int? counted;
    var closeReason = '';
    if (i.kind == 'sale') {
      final s = CheckoutSale.fromIntent(i);
      if (s.tender.kind == 'cash') sales += s.totalCentavos;
    } else if (i.kind == 'refund') {
      final r = RefundIntent.fromMap(i.payload);
      if (r.tenderKind == 'cash') refunds += r.totalRefundCentavos;
    } else if (i.kind == 'voidSale') {
      final v = VoidIntent.fromMap(i.payload);
      if (v.tenderKind == 'cash') refunds += v.voidCentavos;
    } else if (i.kind == 'debtRepayment') {
      final amount = i.payload['amountCentavos'] as int;
      checkoutAmount(amount, minimum: 1);
      if (i.payload['tenderKind'] == 'cash') inside += amount;
    } else if (i.kind == 'cashIn' || i.kind == 'cashOut') {
      final amount = i.payload['amountCentavos'] as int;
      checkoutAmount(amount, minimum: 1);
      checkoutText(i.payload['reason'] as String, 160);
      if (i.kind == 'cashIn') {
        inside += amount;
      } else {
        outside += amount;
      }
    } else if (i.kind == 'closeShift') {
      counted = i.payload['countedCentavos'] as int;
      closeReason = i.payload['reason'] as String;
    } else {
      throw StateError('Invalid shift operation');
    }
    return CashierShift(
        id: id,
        scope: scope,
        openingFloatCentavos: openingFloatCentavos,
        cashSalesCentavos: sales,
        cashInCentavos: inside,
        cashOutCentavos: outside,
        cashRefundCentavos: refunds,
        lastOrdinal: i.ordinal,
        countedCentavos: counted,
        reason: closeReason);
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'scope': scope.toMap(),
        'openingFloatCentavos': openingFloatCentavos,
        'cashSalesCentavos': cashSalesCentavos,
        'cashInCentavos': cashInCentavos,
        'cashOutCentavos': cashOutCentavos,
        'cashRefundCentavos': cashRefundCentavos,
        'lastOrdinal': lastOrdinal,
        'countedCentavos': countedCentavos,
        'reason': reason
      };
  factory CashierShift.fromMap(Map<String, Object?> m) => CashierShift(
      id: m['id'] as String,
      scope: CheckoutScope.fromMap(checkoutMap(m['scope'])),
      openingFloatCentavos: m['openingFloatCentavos'] as int,
      cashSalesCentavos: (m['cashSalesCentavos'] as int?) ?? 0,
      cashInCentavos: (m['cashInCentavos'] as int?) ?? 0,
      cashOutCentavos: (m['cashOutCentavos'] as int?) ?? 0,
      cashRefundCentavos: (m['cashRefundCentavos'] as int?) ?? 0,
      lastOrdinal: (m['lastOrdinal'] as int?) ?? 1,
      countedCentavos: m['countedCentavos'] as int?,
      reason: (m['reason'] as String?) ?? '');
}
