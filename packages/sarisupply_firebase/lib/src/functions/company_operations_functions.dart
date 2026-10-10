import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'https_merchant_gateway.dart';
import 'merchant_application_functions.dart';

final class CompanyOperationsFunctions {
  CompanyOperationsFunctions({required MerchantCallableGateway gateway})
      : _gateway = gateway;
  factory CompanyOperationsFunctions.forDefaultApp() =>
      CompanyOperationsFunctions(
          gateway: HttpsMerchantGateway.forApp(Firebase.app()));
  final MerchantCallableGateway _gateway;

  Future<SupplyingCompany> discover(String merchantId) async {
    final r = await _gateway
        .call('discoverSupplyingCompany', {'merchantId': merchantId});
    if (r['authorizationVersion'] != 1 ||
        r['companyId'] is! String ||
        r['name'] is! String) {
      throw const FormatException('Invalid supplying company');
    }
    return SupplyingCompany(r['companyId'] as String, r['name'] as String);
  }

  Future<CompanyPage> read(
      {required String companyId,
      required Map<String, Object?> context,
      required String kind,
      String? warehouseId,
      String? cursor,
      String? search,
      List<String>? productIds}) async {
    final r = await _gateway.call('readCompanyOperations', {
      'authorizationVersion': 1,
      'companyId': companyId,
      'context': context,
      'kind': kind,
      if (warehouseId != null) 'warehouseId': warehouseId,
      if (cursor != null) 'cursor': cursor,
      if (search != null) 'search': search,
      if (productIds != null) 'productIds': productIds,
    });
    if (r['authorizationVersion'] != 1 ||
        r['companyId'] != companyId ||
        r['records'] is! List ||
        r['hasMore'] is! bool ||
        (r['nextCursor'] != null && r['nextCursor'] is! String) ||
        r['source'] != 'server') {
      throw const FormatException('Invalid company response');
    }
    final records = (r['records'] as List)
        .map((v) => CompanyRecord(Map<String, Object?>.from(v as Map)))
        .toList();
    if ((kind == 'orders' || kind == 'runs') &&
        records.any((r) => r.string('companyId') != companyId)) {
      throw const FormatException('Company record scope mismatch');
    }
    return CompanyPage(
        records: List.unmodifiable(records),
        nextCursor: r['nextCursor'] as String?,
        hasMore: r['hasMore'] as bool);
  }

  Future<String> mutate(
      {required String companyId,
      required Map<String, Object?> context,
      required String action,
      required String operationId,
      required Map<String, Object?> values,
      String? warehouseId}) async {
    final r = await _gateway.call('mutateCompanyOperations', {
      ...values,
      'authorizationVersion': 1,
      'companyId': companyId,
      'context': context,
      'action': action,
      'operationId': operationId,
      if (warehouseId != null) 'warehouseId': warehouseId,
    });
    if (r['authorizationVersion'] != 1 ||
        r['companyId'] != companyId ||
        r['operationId'] != operationId ||
        r['targetId'] is! String ||
        r['status'] is! String) {
      throw const FormatException('Invalid company acknowledgement');
    }
    return r['targetId'] as String;
  }
}
