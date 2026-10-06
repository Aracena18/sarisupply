import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class _Gateway implements MerchantCallableGateway {
  Map<String, Object?>? payload;
  @override
  Future<Map<String, Object?>> call(
      String name, Map<String, Object?> data) async {
    expect(name, 'listManagementRecords');
    payload = data;
    return {
      'records': [
        {
          'id': 'cashier-1',
          'name': 'Ana',
          'code': 'EMP1',
          'status': 'active',
          'branchIds': ['main'],
          'allBranches': false
        }
      ],
      'nextCursor': 'cashier-1'
    };
  }
}

void main() {
  test('management pagination uses human gateway and parses safe projection',
      () async {
    final gateway = _Gateway();
    final page = await ManagementFunctions(gateway: gateway)
        .list('merchant-1', ManagementKind.cashiers, cursor: 'previous');
    expect(gateway.payload,
        {'merchantId': 'merchant-1', 'kind': 'cashiers', 'cursor': 'previous'});
    expect(page.records.single.name, 'Ana');
    expect(page.nextCursor, 'cashier-1');
  });
  test('user errors do not expose raw server or SDK details', () {
    expect(operationErrorMessage(StateError('PIN=secret token=secret')),
        'Unable to complete this action. Try again.');
  });
}
