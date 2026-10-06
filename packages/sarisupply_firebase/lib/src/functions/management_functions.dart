import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'https_merchant_gateway.dart';
import 'merchant_application_functions.dart';

final class ManagementFunctions implements ManagementRepository {
  ManagementFunctions({required MerchantCallableGateway gateway})
      : _gateway = gateway;
  factory ManagementFunctions.forDefaultApp() =>
      ManagementFunctions(gateway: HttpsMerchantGateway.forApp(Firebase.app()));
  final MerchantCallableGateway _gateway;
  @override
  Future<ManagementPage> list(String merchantId, ManagementKind kind,
      {String? cursor}) async {
    final result = await _gateway.call('listManagementRecords', {
      'merchantId': merchantId,
      'kind': kind.name,
      if (cursor != null) 'cursor': cursor,
    });
    final raw = result['records'] as List;
    return ManagementPage(
        records: raw.map((item) {
          final r = Map<String, Object?>.from(item as Map);
          return ManagementRecord(
              id: r['id'] as String,
              name: r['name'] as String,
              code: r['code'] as String,
              status: r['status'] as String,
              branchIds: List<String>.from(r['branchIds'] as List),
              allBranches: r['allBranches'] as bool);
        }).toList(),
        nextCursor: result['nextCursor'] as String?);
  }
}
