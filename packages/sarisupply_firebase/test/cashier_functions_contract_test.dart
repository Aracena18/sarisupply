import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class _Gateway implements MerchantCallableGateway {
  _Gateway(this.response);
  final Map<String, Object?> response;
  final calls = <String>[];
  Map<String, Object?>? payload;

  @override
  Future<Map<String, Object?>> call(
      String name, Map<String, Object?> payload) async {
    calls.add(name);
    this.payload = payload;
    return response;
  }
}

void main() {
  test('human operations and device PIN operations use separate gateways',
      () async {
    final human = _Gateway({
      'cashierId': 'cashier-1',
      'temporaryPin': '123456',
      'credentialVersion': 1,
    });
    final device = _Gateway({
      'cashierId': 'cashier-1',
      'credentialVersion': 1,
      'mustChangePin': true,
    });
    final repository =
        CashierFunctions(humanGateway: human, deviceGateway: device);
    final created = await repository.createCashier(
      merchantId: 'merchant-1',
      displayName: 'Ana',
      employeeCode: 'EMP-1',
      assignedBranchIds: ['branch-a'],
    );
    expect(created.temporaryPin, '123456');
    expect(human.calls, ['createCashier']);
    final verified = await repository.verifyPin('cashier-1', '123456');
    expect(verified.mustChangePin, isTrue);
    expect(device.calls, ['verifyCashierPin']);
    expect(device.payload, {'cashierId': 'cashier-1', 'pin': '123456'});
  });

  test('credential bundle contains metadata without server verifier', () async {
    final device = _Gateway({
      'merchantId': 'merchant-1',
      'branchId': 'branch-a',
      'credentialBundleIssuedAt': '2026-09-27T00:00:00.000Z',
      'credentialBundleExpiresAt': '2026-10-04T00:00:00.000Z',
      'cashiers': [
        {
          'cashierId': 'cashier-1',
          'displayName': 'Ana',
          'employeeCode': 'EMP-1',
          'status': 'active',
          'assignedBranchIds': ['branch-a'],
          'mustChangePin': false,
          'credentialVersion': 2
        }
      ],
    });
    final repository =
        CashierFunctions(humanGateway: _Gateway({}), deviceGateway: device);
    final bundle = await repository.refreshCredentialBundle();
    expect(bundle.cashiers.single.credentialVersion, 2);
    expect(
        bundle.expiresAt.difference(bundle.issuedAt), const Duration(days: 7));
    expect(device.calls, ['refreshCashierCredentialBundle']);
  });

  test('offline failure reports use the authenticated device gateway',
      () async {
    const eventId = 'offline-event-1234567890';
    final human = _Gateway({});
    final device = _Gateway({
      'acceptedEventIds': [eventId]
    });
    final repository =
        CashierFunctions(humanGateway: human, deviceGateway: device);

    final accepted = await repository.reportOfflinePinFailures([
      OfflinePinFailureEvent(
        eventId: eventId,
        cashierId: 'cashier-1',
        failedAttempts: 5,
        occurredAt: DateTime.utc(2026, 9, 28, 12),
      ),
    ]);

    expect(accepted, [eventId]);
    expect(human.calls, isEmpty);
    expect(device.calls, ['reportOfflinePinFailures']);
    expect(device.payload, {
      'events': [
        {
          'eventId': eventId,
          'cashierId': 'cashier-1',
          'failedAttempts': 5,
          'occurredAt': '2026-09-28T12:00:00.000Z',
        }
      ]
    });
  });
}
