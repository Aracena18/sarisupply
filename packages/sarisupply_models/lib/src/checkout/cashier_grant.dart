part of 'checkout.dart';

/// Transport and secure-storage credential. Never put this object in a receipt.
final class IssuedCashierGrant {
  IssuedCashierGrant(
      {required this.scope,
      required this.secret,
      required this.issuedAt,
      required this.expiresAt}) {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(secret) ||
        !expiresAt.isAfter(issuedAt) ||
        expiresAt.difference(issuedAt) > const Duration(days: 7)) {
      throw ArgumentError('Invalid checkout authorization');
    }
  }
  final CheckoutScope scope;
  final String secret;
  final DateTime issuedAt, expiresAt;
  Map<String, Object?> toSecureMap() => {
        'scope': scope.toMap(),
        'secret': secret,
        'issuedAt': issuedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String()
      };
  factory IssuedCashierGrant.fromMap(Map<String, Object?> m) =>
      IssuedCashierGrant(
          scope: CheckoutScope.fromMap(checkoutMap(m['scope'])),
          secret: m['secret'] as String,
          issuedAt: DateTime.parse(m['issuedAt'] as String),
          expiresAt: DateTime.parse(m['expiresAt'] as String));
  @override
  String toString() => 'IssuedCashierGrant(${scope.grantId})';
}

final class CheckoutAuthorization {
  const CheckoutAuthorization(
      {required this.scope,
      required this.occurredAt,
      required this.merchantName,
      required this.branchName});
  final CheckoutScope scope;
  final DateTime occurredAt;
  final String merchantName, branchName;
}

abstract interface class CheckoutGateway {
  Future<CheckoutAck> push(CheckoutIntent intent, IssuedCashierGrant grant);
  Future<List<CatalogChange>> resolveQuotes(
      String merchantId, String branchId, List<CatalogProduct> products);
}
