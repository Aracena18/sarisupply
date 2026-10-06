import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import '../bootstrap/firebase_bootstrap.dart';
import 'https_merchant_gateway.dart';
import 'merchant_application_functions.dart';

final class CheckoutFunctions
    implements CheckoutGateway, CreditGateway, CreditReservationRecovery {
  CheckoutFunctions(this.gateway);
  factory CheckoutFunctions.forDevice() =>
      CheckoutFunctions(HttpsMerchantGateway.forApp(
          Firebase.app(FirebaseBootstrap.deviceAppName)));
  factory CheckoutFunctions.forHuman() =>
      CheckoutFunctions(HttpsMerchantGateway.forApp(Firebase.app()));
  Future<void> approveReversal(CheckoutIntent intent) async {
    final result = await gateway
        .call('approveCheckoutReversal', {'intent': intent.toMap()});
    if (result['operationId'] != intent.id || result['status'] != 'approved') {
      throw const FormatException('Invalid Owner approval acknowledgement');
    }
  }

  final MerchantCallableGateway gateway;
  @override
  Future<List<CustomerAccount>> customers(IssuedCashierGrant grant) async {
    final r = await gateway.call('manageCustomers', {
      'merchantId': grant.scope.merchantId,
      'action': 'list',
      'scope': grant.scope.toMap(),
      'grantSecret': grant.secret
    });
    return (r['customers'] as List)
        .map(
            (c) => CustomerAccount.fromMap(Map<String, Object?>.from(c as Map)))
        .toList();
  }

  @override
  Future<CreditAllowanceGrant> reserveCredit(IssuedCashierGrant grant,
      String customerId, int amountCentavos, String operationId) async {
    final r = await gateway.call('manageCustomers', {
      'merchantId': grant.scope.merchantId,
      'action': 'reserve',
      'scope': grant.scope.toMap(),
      'grantSecret': grant.secret,
      'customerId': customerId,
      'amountCentavos': amountCentavos,
      'operationId': operationId
    });
    final allowance = CreditAllowanceGrant.fromMap(
        Map<String, Object?>.from(r['grant'] as Map));
    if (allowance.id != operationId ||
        allowance.customerId != customerId ||
        allowance.deviceId != grant.scope.deviceId ||
        allowance.allowedCreditCentavos != amountCentavos) {
      throw const FormatException('Credit reservation mismatch');
    }
    return allowance;
  }

  @override
  Future<void> cancelReservation(
      IssuedCashierGrant grant, String customerId, String operationId) async {
    final result = await gateway.call('manageCustomers', {
      'merchantId': grant.scope.merchantId,
      'action': 'cancelReservation',
      'scope': grant.scope.toMap(),
      'grantSecret': grant.secret,
      'customerId': customerId,
      'operationId': operationId
    });
    if (result['status'] != 'cancelled' ||
        result['operationId'] != operationId) {
      throw const FormatException('Reservation cancellation mismatch');
    }
  }

  @override
  Future<CheckoutAck> push(
      CheckoutIntent intent, IssuedCashierGrant grant) async {
    if (grant.scope.toMap().toString() != intent.scope.toMap().toString()) {
      throw const FormatException('Checkout authorization mismatch');
    }
    Map<String, Object?> r;
    try {
      r = await gateway.call('recordCheckoutOperation',
          {'intent': intent.toMap(), 'grantSecret': grant.secret});
    } on FirebaseFunctionsException catch (error) {
      if ([
        'permission-denied',
        'unauthenticated',
        'invalid-argument',
        'failed-precondition',
        'already-exists'
      ].contains(error.code)) {
        return CheckoutAck(intent.id, 'blocked',
            message: 'Reconnect and review this receipt');
      }
      rethrow;
    }
    final accepted = ['accepted', 'duplicate'].contains(r['status']);
    if (r['operationId'] != intent.id ||
        !['accepted', 'duplicate', 'conflict', 'blocked']
            .contains(r['status']) ||
        (accepted &&
            const {'sale', 'refund', 'voidSale'}.contains(intent.kind) &&
            (r['sequence'] is! int || (r['sequence'] as int) < 1)) ||
        (accepted &&
            !const {'sale', 'refund', 'voidSale'}.contains(intent.kind) &&
            r['sequence'] != null)) {
      throw const FormatException('Invalid checkout acknowledgement');
    }
    return CheckoutAck(intent.id, r['status'] as String,
        sequence: r['sequence'] as int?, message: r['message'] as String?);
  }

  @override
  Future<List<CatalogChange>> resolveQuotes(
      String merchantId, String branchId, List<CatalogProduct> products) async {
    if (products.isEmpty || products.length > 20) {
      throw ArgumentError('Select at most twenty products');
    }
    final r = await gateway.call('resolveCatalogQuotes', {
      'merchantId': merchantId,
      'branchId': branchId,
      'products': products
          .map((p) => {'productId': p.id, 'revision': p.revision})
          .toList()
    });
    final raw = r['changes'];
    if (raw is! List || raw.length != products.length) {
      throw const FormatException('Invalid catalog quotes');
    }
    final result = raw.map((item) {
      final c = Map<String, Object?>.from(item as Map);
      final p = CatalogProduct.fromMap(
          Map<String, Object?>.from(c['product'] as Map));
      final sequence = c['sequence'];
      if (sequence is! int || sequence < 1) {
        throw const FormatException('Invalid catalog quote');
      }
      return CatalogChange(sequence, p);
    }).toList();
    for (var n = 0; n < products.length; n++) {
      if (result[n].product.id != products[n].id ||
          result[n].product.revision != products[n].revision) {
        throw const FormatException('Catalog quote mismatch');
      }
    }
    return result;
  }
}
