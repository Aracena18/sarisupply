import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

class Gateway implements MerchantCallableGateway {
  Map<String, Object?> result = {};
  Map<String, Object?>? input;
  String? command;
  Object? error;
  @override
  Future<Map<String, Object?>> call(String c, Map<String, Object?> d) async {
    input = d;
    command = c;
    if (error != null) throw error!;
    return result;
  }
}

final scope = CheckoutScope(
    merchantId: 'm',
    branchId: 'b',
    deviceId: 'd',
    cashierId: 'c',
    grantId: 'g',
    credentialVersion: 1);
final now = DateTime.utc(2026, 10, 5);
final grant = IssuedCashierGrant(
    scope: scope,
    secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    issuedAt: now,
    expiresAt: now.add(const Duration(days: 7)));
final intent = CheckoutIntent(
    id: 'shift',
    scope: scope,
    shiftId: 'shift',
    ordinal: 1,
    occurredAt: now,
    kind: 'openShift',
    payload: {'floatCentavos': 0});
void main() {
  test('Owner approval must acknowledge the exact operation', () async {
    final g = Gateway()
      ..result = {'operationId': intent.id, 'status': 'approved'};
    final api = CheckoutFunctions(g);
    await api.approveReversal(intent);
    expect(g.command, 'approveCheckoutReversal');
    g.result = {'operationId': 'foreign', 'status': 'approved'};
    await expectLater(api.approveReversal(intent), throwsFormatException);
  });
  test('sends secret separately and pins intent acknowledgement', () async {
    final g = Gateway()
      ..result = {'operationId': 'shift', 'status': 'accepted'};
    final api = CheckoutFunctions(g);
    expect((await api.push(intent, grant)).status, 'accepted');
    expect(g.command, 'recordCheckoutOperation');
    expect(g.input!['grantSecret'], grant.secret);
    expect(g.input!['intent'].toString(), isNot(contains(grant.secret)));
    g.result = {'operationId': 'foreign', 'status': 'accepted'};
    await expectLater(api.push(intent, grant), throwsFormatException);
    g.result = {'operationId': 'shift', 'status': 'accepted', 'sequence': 1};
    await expectLater(api.push(intent, grant), throwsFormatException);
  });
  test(
      'quota and timeout stay retryable; permanent denial blocks without leaking',
      () async {
    final g = Gateway();
    final api = CheckoutFunctions(g);
    for (final code in [
      'resource-exhausted',
      'unavailable',
      'deadline-exceeded'
    ]) {
      g.error = FirebaseFunctionsException(code: code, message: grant.secret);
      await expectLater(
          api.push(intent, grant), throwsA(isA<FirebaseFunctionsException>()));
    }
    g.error = FirebaseFunctionsException(
        code: 'permission-denied', message: grant.secret);
    final ack = await api.push(intent, grant);
    expect(ack.status, 'blocked');
    expect(ack.message, isNot(contains(grant.secret)));
  });
  test('normalizes legacy counts and keeps entire multi-product sale event',
      () async {
    final g = Gateway()
      ..result = {
        'cursor': 2,
        'hasMore': false,
        'changes': [
          {
            'sequence': 1,
            'operationId': 'count',
            'productId': 'p',
            'quantity': 12,
            'revision': 1
          },
          {
            'sequence': 2,
            'operationId': 'sale',
            'kind': 'sale',
            'positions': [
              {'productId': 'p', 'quantity': 6, 'revision': 2, 'delta': -6},
              {'productId': 'q', 'quantity': -1, 'revision': 1, 'delta': -1}
            ]
          }
        ]
      };
    final page = await InventoryFunctions(gateway: g).pullStock('m', 'b', 0);
    expect(page.changes.first.kind, 'count');
    expect(page.changes.first.positions.single.delta, isNull);
    expect(page.changes.last.positions.map((p) => p.delta), [-6, -1]);
  });
}
