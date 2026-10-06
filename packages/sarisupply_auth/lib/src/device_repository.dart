abstract interface class DeviceTokenSession {
  Future<String> signInWithCustomToken(String token);
  Future<void> signOut();
}

final class DeviceActivation {
  const DeviceActivation({
    required this.deviceId,
    required this.merchantId,
    required this.branchId,
  });

  final String deviceId;
  final String merchantId;
  final String branchId;
}

final class DeviceBootstrap {
  const DeviceBootstrap({
    required this.deviceId,
    required this.merchantId,
    required this.branchId,
    required this.displayName,
    this.merchantName,
    this.branchName,
  });

  final String deviceId;
  final String merchantId;
  final String branchId;
  final String displayName;
  final String? merchantName, branchName;
}

abstract interface class DeviceRepository {
  Future<DeviceActivation> activate({
    required String merchantId,
    required String branchId,
    required String displayName,
    required String platform,
    required String appVersion,
    required String operationId,
    bool keepHumanSignedIn = false,
  });

  Future<void> revoke(String merchantId, String deviceId);
  Future<DeviceBootstrap> getBootstrap();
}
