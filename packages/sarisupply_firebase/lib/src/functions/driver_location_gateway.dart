import 'package:sarisupply_models/sarisupply_models.dart';

abstract interface class DriverLocationGateway {
  Future<DriverLocationSnapshot> updateDriverLocation(
      String merchantId, String runId, DriverLocationFix fix, int eventAtMs);
  Future<void> pauseDriverLocation(
      String merchantId, String runId, int eventAtMs);
  Future<DriverLocationSnapshot?> readDriverLocation(
      String merchantId, String runId);
}
