import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class _Gateway implements MerchantCallableGateway {
  String? name;
  Map<String, Object?>? payload;
  final List<String> calls = [];

  @override
  Future<Map<String, Object?>> call(
      String name, Map<String, Object?> payload) async {
    this.name = name;
    this.payload = payload;
    calls.add(name);
    if (name == 'activatePosDevice') {
      return {
        'deviceId': 'device-1',
        'merchantId': 'merchant-1',
        'branchId': 'branch-1',
        'customToken': 'custom-token'
      };
    }
    if (name == 'getDeviceBootstrap') {
      return {
        'deviceId': 'device-1',
        'merchantId': 'merchant-1',
        'branchId': 'branch-1',
        'displayName': 'Counter tablet'
      };
    }
    return {'status': 'revoked'};
  }
}

class _HumanAuth extends Fake implements FirebaseAuth {
  int signOutCount = 0;
  @override
  Future<void> signOut() async {
    signOutCount++;
  }
}

class _DeviceSession implements DeviceTokenSession {
  String? token;
  @override
  Future<String> signInWithCustomToken(String token) async {
    this.token = token;
    return 'device:device-1';
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  test('activation signs the separate device session in and clears human auth',
      () async {
    final human = _HumanAuth();
    final device = _DeviceSession();
    final humanGateway = _Gateway();
    final deviceGateway = _Gateway();
    final repository = DeviceFunctions(
      humanAuth: human,
      deviceSession: device,
      humanGateway: humanGateway,
      deviceGateway: deviceGateway,
    );
    final result = await repository.activate(
      merchantId: 'merchant-1',
      branchId: 'branch-1',
      displayName: 'Counter tablet',
      platform: 'android',
      appVersion: '0.1.0',
      operationId: 'activate-1',
    );
    expect(result.deviceId, 'device-1');
    expect(device.token, 'custom-token');
    expect(human.signOutCount, 1);
    expect(humanGateway.name, 'activatePosDevice');
    expect(humanGateway.payload?['operationId'], 'activate-1');
    final bootstrap = await repository.getBootstrap();
    expect(bootstrap.branchId, 'branch-1');
    expect(deviceGateway.calls, ['getDeviceBootstrap']);
  });

  test('Owner settings may keep the human session after activation', () async {
    final human = _HumanAuth();
    final repository = DeviceFunctions(
      humanAuth: human,
      deviceSession: _DeviceSession(),
      humanGateway: _Gateway(),
      deviceGateway: _Gateway(),
    );
    await repository.activate(
      merchantId: 'merchant-1',
      branchId: 'branch-1',
      displayName: 'Counter tablet',
      platform: 'android',
      appVersion: '0.1.0',
      operationId: 'activate-2',
      keepHumanSignedIn: true,
    );
    expect(human.signOutCount, 0);
  });
}
