import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import '../features/cashier_auth/data/offline_clock_source.dart';
import '../features/cashier_auth/data/secure_offline_credential_store.dart';
import '../features/cashier_auth/domain/cashier_login_service.dart';
import 'pos_app_gate.dart';

final class FirebasePosWorkflow implements PosWorkflow {
  FirebasePosWorkflow({
    FirebaseAuth? humanAuth,
    FirebaseAuth? deviceAuth,
    AuthRepository? humanIdentity,
    MerchantApplicationRepository? applications,
    MembershipRepository? memberships,
    DeviceRepository? devices,
    CashierRepository? cashiers,
    SecureOfflineCredentialStore? store,
    OfflineClockSource? offlineClock,
    DateTime Function()? clock,
  })  : _humanAuth = humanAuth ?? FirebaseAuth.instanceFor(app: Firebase.app()),
        _deviceAuth = deviceAuth ??
            FirebaseAuth.instanceFor(
                app: Firebase.app(FirebaseBootstrap.deviceAppName)),
        _humanIdentity = humanIdentity ??
            FirebaseGoogleAuthRepository.forDefaultApp(
              serverClientId: _serverClientId(),
            ),
        applications =
            applications ?? MerchantApplicationFunctions.forDefaultApp(),
        memberships = memberships ?? MembershipFunctions.forDefaultApp(),
        devices = devices ?? DeviceFunctions.forInitializedApps(),
        _cashiers = cashiers ?? CashierFunctions.forInitializedApps(),
        _store = store ?? SecureOfflineCredentialStore(),
        _offlineClock = offlineClock ?? const AndroidOfflineClockSource(),
        _clock = clock ?? DateTime.now;

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
  final SecureOfflineCredentialStore _store;
  final OfflineClockSource _offlineClock;
  final DateTime Function() _clock;
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
        final verifiedAt = _clock().toUtc();
        final reading = await _offlineClock.read();
        await _store.saveDeviceContext(StoredDeviceContext(
          deviceId: bootstrap.deviceId,
          merchantId: bootstrap.merchantId,
          branchId: bootstrap.branchId,
          verifiedAt: verifiedAt,
          lastObservedWallClock: verifiedAt,
          clockAnchor: reading == null
              ? null
              : OfflineClockAnchor(
                  wallClock: verifiedAt,
                  bootCount: reading.bootCount,
                  elapsedRealtime: reading.elapsedRealtime,
                ),
        ));
        await _trySyncQueuedSecurityEvents();
        return PosGateSnapshot(
          state: PosGateState.deviceReadyCashierLocked,
          deviceId: _deviceId,
          merchantId: bootstrap.merchantId,
          branchId: bootstrap.branchId,
        );
      } on FirebaseFunctionsException catch (error) {
        if (error.code == 'permission-denied' ||
            error.code == 'unauthenticated') {
          return const PosGateSnapshot(state: PosGateState.deviceRevoked);
        }
        if (_isNetworkError(error.code)) {
          final now = _clock().toUtc();
          final reading = await _offlineClock.read();
          final context = await _store.readDeviceContext(_deviceId!);
          if (context == null ||
              !context.isUsableAt(OfflineTimeEvidence(
                now: now,
                lastObservedWallClock: context.lastObservedWallClock,
                anchor: context.clockAnchor,
                reading: reading,
              ))) {
            return const PosGateSnapshot(
                state: PosGateState.offlineCredentialsExpired);
          }
          await _store
              .saveDeviceContext(context.copyWith(lastObservedWallClock: now));
          return PosGateSnapshot(
            state: PosGateState.deviceReadyCashierLocked,
            deviceId: _deviceId,
            merchantId: context.merchantId,
            branchId: context.branchId,
          );
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

  Future<void> _trySyncQueuedSecurityEvents() async {
    try {
      await _loginService().syncQueuedSecurityEvents();
    } on Exception {
      // An upload failure does not discard events or block POS recovery.
    }
  }

  @override
  Future<CashierLoginResult> loginCashier(String cashierId, String pin) async {
    final service = _loginService();
    try {
      final result = await service.loginOnline(cashierId, pin);
      await _trySyncQueuedSecurityEvents();
      return result;
    } on FirebaseFunctionsException catch (error) {
      if (!_isNetworkError(error.code)) rethrow;
      return service.loginOffline(cashierId, pin);
    }
  }

  @override
  Future<CashierLoginResult> changePin(
      String cashierId, String currentPin, String newPin) async {
    await _cashiers.changePin(cashierId, currentPin, newPin);
    final result = await _loginService().loginOnline(cashierId, newPin);
    await _trySyncQueuedSecurityEvents();
    return result;
  }
}
