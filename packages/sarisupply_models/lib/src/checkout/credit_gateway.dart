import 'checkout.dart';
import 'customer_credit.dart';

abstract interface class CreditGateway {
  Future<List<CustomerAccount>> customers(IssuedCashierGrant grant);
  Future<CreditAllowanceGrant> reserveCredit(IssuedCashierGrant grant,
      String customerId, int amountCentavos, String operationId);
}

abstract interface class CreditReservationRecovery {
  Future<void> cancelReservation(
      IssuedCashierGrant grant, String customerId, String operationId);
}
