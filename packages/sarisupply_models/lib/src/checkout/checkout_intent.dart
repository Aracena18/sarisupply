part of 'checkout.dart';

final class CheckoutScope {
  CheckoutScope(
      {required this.merchantId,
      required this.branchId,
      required this.deviceId,
      required this.cashierId,
      required this.grantId,
      required this.credentialVersion}) {
    for (final id in [merchantId, branchId, deviceId, cashierId, grantId]) {
      checkoutId(id);
    }
    if (credentialVersion < 1) {
      throw ArgumentError('Invalid credential version');
    }
  }
  final String merchantId, branchId, deviceId, cashierId, grantId;
  final int credentialVersion;
  bool sameCashier(CheckoutScope s) =>
      merchantId == s.merchantId &&
      branchId == s.branchId &&
      deviceId == s.deviceId &&
      cashierId == s.cashierId;
  Map<String, Object?> toMap() => {
        'merchantId': merchantId,
        'branchId': branchId,
        'deviceId': deviceId,
        'cashierId': cashierId,
        'grantId': grantId,
        'credentialVersion': credentialVersion
      };
  factory CheckoutScope.fromMap(Map<String, Object?> m) => CheckoutScope(
      merchantId: m['merchantId'] as String,
      branchId: m['branchId'] as String,
      deviceId: m['deviceId'] as String,
      cashierId: m['cashierId'] as String,
      grantId: m['grantId'] as String,
      credentialVersion: m['credentialVersion'] as int);
}

final class CheckoutIntent {
  CheckoutIntent(
      {required this.id,
      required this.scope,
      required this.shiftId,
      required this.ordinal,
      required this.occurredAt,
      required this.kind,
      required Map<String, Object?> payload,
      this.status = 'pending',
      this.sequence,
      this.message})
      : payload = _freezeCheckout(payload) as Map<String, Object?> {
    checkoutId(id);
    checkoutId(shiftId);
    if (ordinal < 1 ||
        ![
          'openShift',
          'sale',
          'cashIn',
          'cashOut',
          'closeShift',
          'refund',
          'voidSale',
          'debtRepayment'
        ].contains(kind)) {
      throw ArgumentError('Invalid checkout intent');
    }
  }
  final String id, shiftId, kind, status;
  final CheckoutScope scope;
  final int ordinal;
  final DateTime occurredAt;
  final Map<String, Object?> payload;
  final int? sequence;
  final String? message;
  Map<String, Object?> toMap() => {
        'id': id,
        'scope': scope.toMap(),
        'shiftId': shiftId,
        'ordinal': ordinal,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'kind': kind,
        'payload': payload
      };
  String get fingerprint => jsonEncode(toMap());
  factory CheckoutIntent.fromMap(Map<String, Object?> m,
          {String status = 'pending', int? sequence, String? message}) =>
      CheckoutIntent(
          id: m['id'] as String,
          scope: CheckoutScope.fromMap(checkoutMap(m['scope'])),
          shiftId: m['shiftId'] as String,
          ordinal: m['ordinal'] as int,
          occurredAt: DateTime.parse(m['occurredAt'] as String),
          kind: m['kind'] as String,
          payload: checkoutMap(m['payload']),
          status: status,
          sequence: sequence,
          message: message);
}

final class CheckoutAck {
  const CheckoutAck(this.operationId, this.status,
      {this.sequence, this.message});
  final String operationId, status;
  final int? sequence;
  final String? message;
}
