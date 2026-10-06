import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'https_merchant_gateway.dart';
import 'merchant_application_functions.dart';

final class CustomerFunctions {
  CustomerFunctions(this.gateway);
  factory CustomerFunctions.forHuman() =>
      CustomerFunctions(HttpsMerchantGateway.forApp(Firebase.app()));
  final MerchantCallableGateway gateway;
  Future<CustomerAccount> save(
      String merchantId, CustomerAccount customer) async {
    final r = await gateway.call('manageCustomers', {
      'merchantId': merchantId,
      'action': 'save',
      'customerId': customer.id,
      'customer': customer.toMap()
    });
    return CustomerAccount.fromMap(
        Map<String, Object?>.from(r['customer'] as Map));
  }
}
