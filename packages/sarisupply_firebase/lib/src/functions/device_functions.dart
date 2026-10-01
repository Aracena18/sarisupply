import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

import '../auth/firebase_device_auth_repository.dart';
import '../bootstrap/firebase_bootstrap.dart';
import 'merchant_application_functions.dart';

final class DeviceFunctions implements DeviceRepository {
  DeviceFunctions({
    required FirebaseAuth humanAuth,
    required DeviceTokenSession deviceSession,
    required MerchantCallableGateway humanGateway,
    required MerchantCallableGateway deviceGateway,
  })  : _humanAuth = humanAuth,
        _deviceSession = deviceSession,
        _humanGateway = humanGateway,
        _deviceGateway = deviceGateway;

  factory DeviceFunctions.forInitializedApps() {
    final humanApp = Firebase.app();
    final deviceApp = Firebase.app(FirebaseBootstrap.deviceAppName);
    return DeviceFunctions(
      humanAuth: FirebaseAuth.instanceFor(app: humanApp),
      deviceSession: FirebaseDeviceAuthRepository.forApp(deviceApp),
      humanGateway: FirebaseMerchantCallableGateway(
        FirebaseFunctions.instanceFor(app: humanApp, region: 'asia-southeast1'),
      ),
      deviceGateway: FirebaseMerchantCallableGateway(
        FirebaseFunctions.instanceFor(
            app: deviceApp, region: 'asia-southeast1'),
      ),
    );
  }

  final FirebaseAuth _humanAuth;
  final DeviceTokenSession _deviceSession;
  final MerchantCallableGateway _humanGateway;
  final MerchantCallableGateway _deviceGateway;

  @override
  Future<DeviceActivation> activate({
    required String merchantId,
    required String branchId,
    required String displayName,
    required String platform,
    required String appVersion,
    required String operationId,
    bool keepHumanSignedIn = false,
  }) async {
    final response = await _humanGateway.call('activatePosDevice', {
      'merchantId': merchantId,
      'branchId': branchId,
      'displayName': displayName,
      'platform': platform,
      'appVersion': appVersion,
      'operationId': operationId,
    });
    final deviceId = response['deviceId'];
    final activatedMerchantId = response['merchantId'];
    final activatedBranchId = response['branchId'];
    final token = response['customToken'];
    if (deviceId is! String ||
        activatedMerchantId is! String ||
        activatedBranchId is! String ||
        token is! String) {
      throw StateError('Device activation returned an invalid response');
    }
    final signedInUid = await _deviceSession.signInWithCustomToken(token);
    if (signedInUid != 'device:$deviceId') {
      await _deviceSession.signOut();
      throw StateError('Device sign-in returned a different identity');
    }
    if (!keepHumanSignedIn) await _humanAuth.signOut();
    return DeviceActivation(
      deviceId: deviceId,
      merchantId: activatedMerchantId,
      branchId: activatedBranchId,
    );
  }

  @override
  Future<void> revoke(String merchantId, String deviceId) async {
    await _humanGateway.call('revokePosDevice', {
      'merchantId': merchantId,
      'deviceId': deviceId,
    });
  }

  @override
  Future<DeviceBootstrap> getBootstrap() async {
    final response = await _deviceGateway.call('getDeviceBootstrap', {});
    return DeviceBootstrap(
      deviceId: response['deviceId'] as String,
      merchantId: response['merchantId'] as String,
      branchId: response['branchId'] as String,
      displayName: response['displayName'] as String,
    );
  }
}
