import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'https_merchant_gateway.dart';
import 'merchant_application_functions.dart';

final class OperationsFunctions {
  OperationsFunctions(this.gateway);
  factory OperationsFunctions.forAdmin() =>
      OperationsFunctions(HttpsMerchantGateway.forApp(Firebase.app()));
  final MerchantCallableGateway gateway;
  Future<List<Map<String, Object?>>> merchants() async {
    final r =
        await gateway.call('readOperationalWorkspace', {'action': 'merchants'});
    return (r['merchants'] as List)
        .map((m) => Map<String, Object?>.from(m as Map))
        .toList();
  }

  Future<Map<String, Object?>> procurement(String merchantId, String kind) =>
      gateway.call('readOperationalWorkspace',
          {'action': 'procurement', 'merchantId': merchantId, 'kind': kind});

  Future<List<DailySalesSummary>> reports(
      String merchantId, String date) async {
    final r = await gateway.call('readOperationalWorkspace',
        {'action': 'reports', 'merchantId': merchantId, 'date': date});
    return (r['summaries'] as List)
        .map((s) =>
            DailySalesSummary.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList();
  }
}
