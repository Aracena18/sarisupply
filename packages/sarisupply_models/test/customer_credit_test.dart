import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  group('CustomerAccount & CreditAllowanceGrant', () {
    test('CustomerAccount tracks available credit and enforces limits', () {
      final customer = CustomerAccount(
        id: 'cust_juan',
        name: 'Juan Dela Cruz',
        phone: '09171234567',
        creditLimitCentavos: 50000, // PHP 500.00
        balanceCentavos: 20000, // PHP 200.00 debt
      );

      expect(customer.availableCreditCentavos, 30000);
      expect(customer.canCharge(30000), true);
      expect(customer.canCharge(30001), false);
      expect(customer.canCharge(-100), false);

      final updated = customer.withBalance(50000);
      expect(updated.availableCreditCentavos, 0);
      expect(updated.canCharge(1), false);
    });

    test('inactive customer account blocks all credit charges', () {
      final inactive = CustomerAccount(
        id: 'cust_maria',
        name: 'Maria Santos',
        phone: '09181234567',
        creditLimitCentavos: 50000,
        balanceCentavos: 0,
        active: false,
      );

      expect(inactive.availableCreditCentavos, 0);
      expect(inactive.canCharge(1000), false);
    });

    test('CreditAllowanceGrant enforces offline limits and expiration', () {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      final expires = DateTime.utc(2026, 10, 5, 18, 0, 0);

      final grant = CreditAllowanceGrant(
        id: 'grant_1',
        customerId: 'cust_juan',
        deviceId: 'dev_pos_1',
        allowedCreditCentavos: 20000, // PHP 200.00 offline limit
        usedCreditCentavos: 5000,
        expiresAt: expires,
      );

      expect(grant.remainingAllowanceCentavos, 15000);
      expect(grant.canChargeOffline(15000, now), true);
      expect(grant.canChargeOffline(15001, now), false);

      // Expired grant rejected even if remaining allowance exists
      final pastExpiry = DateTime.utc(2026, 10, 5, 19, 0, 0);
      expect(grant.isExpiredAt(pastExpiry), true);
      expect(grant.canChargeOffline(1000, pastExpiry), false);

      final updatedGrant = grant.withUsed(10000);
      expect(updatedGrant.usedCreditCentavos, 15000);
      expect(updatedGrant.remainingAllowanceCentavos, 5000);
    });

    test('DebtRepayment validates positive amount and tender kind', () {
      final repayment = DebtRepayment(
        id: 'rep_1',
        customerId: 'cust_juan',
        amountCentavos: 10000,
        tenderKind: 'cash',
        occurredAt: DateTime.utc(2026, 10, 5, 12, 30, 0),
        shiftId: 'shift_1',
        cashierId: 'cashier_1',
      );

      expect(repayment.amountCentavos, 10000);
      expect(repayment.tenderKind, 'cash');

      expect(
        () => DebtRepayment(
          id: 'rep_bad',
          customerId: 'cust_juan',
          amountCentavos: 0,
          tenderKind: 'cash',
          occurredAt: DateTime.utc(2026, 10, 5, 12, 30, 0),
        ),
        throwsArgumentError,
      );

      expect(
        () => DebtRepayment(
          id: 'rep_bad_tender',
          customerId: 'cust_juan',
          amountCentavos: 5000,
          tenderKind: 'credit', // Repayment cannot be credit!
          occurredAt: DateTime.utc(2026, 10, 5, 12, 30, 0),
        ),
        throwsArgumentError,
      );
    });
  });
}
