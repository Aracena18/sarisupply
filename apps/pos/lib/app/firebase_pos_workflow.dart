import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import '../features/cashier_auth/data/secure_offline_credential_store.dart';
import '../features/cashier_auth/domain/cashier_login_service.dart';
import 'pos_app_gate.dart';

final class FirebasePosWorkflow implements PosWorkflow {
  FirebasePosWorkflow()
      : _humanAuth = FirebaseAuth.instanceFor(app: Firebase.app()),
        _deviceAuth = FirebaseAuth.instanceFor(
            app: Firebase.app(FirebaseBootstrap.deviceAppName)),
        _humanIdentity = FirebaseGoogleAuthRepository.forDefaultApp(
          serverClientId: _serverClientId(),
        ),
        applications = MerchantApplicationFunctions.forDefaultApp(),
        memberships = MembershipFunctions.forDefaultApp(),
        devices = DeviceFunctions.forInitializedApps(),
        _cashiers = CashierFunctions.forInitializedApps();

  static String _serverClientId() {
    const supplied = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    if (supplied.isNotEmpty) return supplied;
    return switch (Firebase.app().options.projectId) {
      'sarisupply-dev-aracena18' =>
        '594903185972-1dlngb8a6i0j6i87ss6nbaab2u1krdqg.apps.googleusercontent.com',
      'sarisupply-prod-aracena18' =>
        '110781011916-88507t6k0glkskp51460qa6bcm6oti8b.apps.googleusercontent.com',
      _ => '',
    };
  }

  final FirebaseAuth _humanAuth;
  final FirebaseAuth _deviceAuth;
  final AuthRepository _humanIdentity;
  final CashierRepository _cashiers;
  final SecureOfflineCredentialStore _store = SecureOfflineCredentialStore();
  String? _deviceId;

  @override
  final MerchantApplicationRepository applications;
  @override
  final MembershipRepository memberships;
  @override
  final DeviceRepository devices;

  @override
  Future<PosGateSnapshot> load() async {
    final deviceUser = _deviceAuth.currentUser;
    if (deviceUser != null) {
      _deviceId = deviceUser.uid.startsWith('device:')
          ? deviceUser.uid.substring('device:'.length)
          : null;
      if (_deviceId == null) {
        return const PosGateSnapshot(state: PosGateState.deviceRevoked);
      }
      try {
        final bootstrap = await devices.getBootstrap();
        if (bootstrap.deviceId != _deviceId) {
          return const PosGateSnapshot(state: PosGateState.deviceRevoked);
        }
        return PosGateSnapshot(
            state: PosGateState.deviceReadyCashierLocked, deviceId: _deviceId);
      } on FirebaseFunctionsException catch (error) {
        if (error.code == 'permission-denied' ||
            error.code == 'unauthenticated') {
          return const PosGateSnapshot(state: PosGateState.deviceRevoked);
        }
        if (_isNetworkError(error.code)) {
          return PosGateSnapshot(
              state: PosGateState.deviceReadyCashierLocked,
              deviceId: _deviceId);
        }
        rethrow;
      }
    }
    if (_humanAuth.currentUser == null) {
      return const PosGateSnapshot(state: PosGateState.signedOut);
    }
    final active = await memberships.listMyMemberships();
    if (active.isNotEmpty) {
      return PosGateSnapshot(
        state: PosGateState.approvedNeedsDeviceActivation,
        memberships: active,
      );
    }
    final applicationsForUser = await applications.watchMyApplications().first;
    MerchantApplication? latest;
    if (applicationsForUser.isNotEmpty) {
      applicationsForUser.sort((a, b) => (a.submittedAt ??
              DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      latest = applicationsForUser.last;
    }
    if (latest?.status == MerchantApplicationStatus.pendingReview) {
      return PosGateSnapshot(
          state: PosGateState.pendingMerchant, application: latest);
    }
    return PosGateSnapshot(state: PosGateState.noMerchant, application: latest);
  }

  @override
  Future<void> signIn() async {
    await _humanIdentity.signInWithGoogle();
  }

  @override
  Future<void> signOutHuman() => _humanIdentity.signOut();

  @override
  Future<void> clearDeviceSession() async {
    final oldDeviceId = _deviceId;
    await _deviceAuth.signOut();
    if (oldDeviceId != null) await _store.deleteForDevice(oldDeviceId);
    _deviceId = null;
  }

  CashierLoginService _loginService() {
    final id = _deviceId;
    if (id == null) throw StateError('This tablet is not activated');
    return CashierLoginService(
        cashiers: _cashiers, store: _store, deviceId: id);
  }

  static bool _isNetworkError(String code) =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'network-request-failed';

  @override
  Future<CashierLoginResult> loginCashier(String cashierId, String pin) async {
    final service = _loginService();
    try {
      return await service.loginOnline(cashierId, pin);
    } on FirebaseFunctionsException catch (error) {
      if (!_isNetworkError(error.code)) rethrow;
      return service.loginOffline(cashierId, pin);
    }
  }

  @override
  Future<CashierLoginResult> changePin(
      String cashierId, String currentPin, String newPin) async {
    await _cashiers.changePin(cashierId, currentPin, newPin);
    return _loginService().loginOnline(cashierId, newPin);
  }
}
