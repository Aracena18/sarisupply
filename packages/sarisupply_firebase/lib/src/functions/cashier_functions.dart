import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

import '../bootstrap/firebase_bootstrap.dart';
import 'merchant_application_functions.dart';

final class CashierFunctions implements CashierRepository {
  CashierFunctions({
    required MerchantCallableGateway humanGateway,
    required MerchantCallableGateway deviceGateway,
  })  : _humanGateway = humanGateway,
        _deviceGateway = deviceGateway;

  factory CashierFunctions.forInitializedApps() {
    final humanApp = Firebase.app();
    final deviceApp = Firebase.app(FirebaseBootstrap.deviceAppName);
    return CashierFunctions(
      humanGateway: FirebaseMerchantCallableGateway(
        FirebaseFunctions.instanceFor(app: humanApp, region: 'asia-southeast1'),
      ),
      deviceGateway: FirebaseMerchantCallableGateway(
        FirebaseFunctions.instanceFor(
            app: deviceApp, region: 'asia-southeast1'),
      ),
    );
  }

  final MerchantCallableGateway _humanGateway;
  final MerchantCallableGateway _deviceGateway;

  static IssuedCashierPin _issued(Map<String, Object?> result) =>
      IssuedCashierPin(
        cashierId: result['cashierId'] as String,
        temporaryPin: result['temporaryPin'] as String,
        credentialVersion: result['credentialVersion'] as int,
      );

  @override
  Future<IssuedCashierPin> createCashier({
    required String merchantId,
    required String displayName,
    required String employeeCode,
    required List<String> assignedBranchIds,
  }) async =>
      _issued(await _humanGateway.call('createCashier', {
        'merchantId': merchantId,
        'displayName': displayName,
        'employeeCode': employeeCode,
        'assignedBranchIds': assignedBranchIds,
      }));

  @override
  Future<void> setCashierStatus(
      String merchantId, String cashierId, String status) async {
    await _humanGateway.call('setCashierStatus', {
      'merchantId': merchantId,
      'cashierId': cashierId,
      'status': status,
    });
  }

  @override
  Future<CashierPinVerification> verifyPin(String cashierId, String pin) async {
    final result = await _deviceGateway.call('verifyCashierPin', {
      'cashierId': cashierId,
      'pin': pin,
    });
    return CashierPinVerification(
      cashierId: result['cashierId'] as String,
      credentialVersion: result['credentialVersion'] as int,
      mustChangePin: result['mustChangePin'] as bool,
    );
  }

  @override
  Future<int> changePin(
      String cashierId, String currentPin, String newPin) async {
    final result = await _deviceGateway.call('changeCashierPin', {
      'cashierId': cashierId,
      'currentPin': currentPin,
      'newPin': newPin,
    });
    return result['credentialVersion'] as int;
  }

  @override
  Future<IssuedCashierPin> resetPin(
          String merchantId, String cashierId) async =>
      _issued(await _humanGateway.call('resetCashierPin', {
        'merchantId': merchantId,
        'cashierId': cashierId,
      }));

  @override
  Future<CashierCredentialBundle> refreshCredentialBundle() async {
    final result =
        await _deviceGateway.call('refreshCashierCredentialBundle', {});
    final rawCashiers = result['cashiers'] as List;
    return CashierCredentialBundle(
      merchantId: result['merchantId'] as String,
      branchId: result['branchId'] as String,
      issuedAt: DateTime.parse(result['credentialBundleIssuedAt'] as String),
      expiresAt: DateTime.parse(result['credentialBundleExpiresAt'] as String),
      cashiers: rawCashiers.map((raw) {
        final data = Map<String, Object?>.from(raw as Map);
        return CashierCredentialProjection(
          cashierId: data['cashierId'] as String,
          displayName: data['displayName'] as String,
          employeeCode: data['employeeCode'] as String,
          status: data['status'] as String,
          assignedBranchIds:
              List<String>.from(data['assignedBranchIds'] as List),
          mustChangePin: data['mustChangePin'] as bool,
          credentialVersion: data['credentialVersion'] as int,
        );
      }).toList(),
    );
  }
}
