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
  @override
  InventoryGateway get humanInventory => InventoryFunctions.forHuman();
  @override
  InventoryGateway get deviceInventory => InventoryFunctions.forDevice();
  @override
  CheckoutGateway get checkoutGateway => CheckoutFunctions.forDevice();
  FirebasePosWorkflow({
    FirebaseAuth? humanAuth,
    FirebaseAuth? deviceAuth,
    AuthRepository? humanIdentity,
    MerchantApplicationRepository? applications,
    MembershipRepository? memberships,
    DeviceRepository? devices,
    CashierRepository? cashiers,
    ManagementRepository? management,
    SecureOfflineCredentialStore? store,
    OfflineClockSource? offlineClock,
    DateTime Function()? clock,
  })  : _humanAuth = humanAuth ?? FirebaseAuth.instanceFor(app: Firebase.app()),
        _deviceAuth = deviceAuth ??
            FirebaseAuth.instanceFor(
                app: Firebase.app(FirebaseBootstrap.deviceAppName)),
        _humanIdentity =
            humanIdentity ?? FirebaseGoogleAuthRepository.forDefaultApp(),
        applications =
            applications ?? MerchantApplicationFunctions.forDefaultApp(),
        memberships = memberships ?? MembershipFunctions.forDefaultApp(),
        devices = devices ?? DeviceFunctions.forInitializedApps(),
        _cashiers = cashiers ?? CashierFunctions.forInitializedApps(),
        _management = management,
        _store = store ?? SecureOfflineCredentialStore(),
        _offlineClock = offlineClock ?? const AndroidOfflineClockSource(),
        _clock = clock ?? DateTime.now;

  final FirebaseAuth _humanAuth;
  final FirebaseAuth _deviceAuth;
  final AuthRepository _humanIdentity;
  final CashierRepository _cashiers;
  final ManagementRepository? _management;
  @override
  CashierRepository get cashiers => _cashiers;
  @override
  ManagementRepository get management =>
      _management ?? ManagementFunctions.forDefaultApp();

  @override
  Future<List<CashierCredentialProjection>> listCashiers() async {
    final id = _deviceId;
    if (id == null) return [];
    try {
      final bundle = await _cashiers.refreshCredentialBundle();
      final roster =
          bundle.cashiers.where((c) => c.status == 'active').toList();
      await _store.saveRoster(id, roster);
      return roster;
    } on FirebaseFunctionsException catch (error) {
      if (!_isNetworkError(error.code)) rethrow;
      return _store.readRoster(id);
    }
  }

  final SecureOfflineCredentialStore _store;
  final OfflineClockSource _offlineClock;
  final DateTime Function() _clock;
  String? _deviceId;
  CashierSession? _activeSession;

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
        await _invalidateDeviceAuthorization();
        return const PosGateSnapshot(state: PosGateState.deviceRevoked);
      }
      try {
        final bootstrap = await devices.getBootstrap();
        if (bootstrap.deviceId != _deviceId) {
          await _invalidateDeviceAuthorization();
          return const PosGateSnapshot(state: PosGateState.deviceRevoked);
        }
        final verifiedAt = _clock().toUtc();
        final reading = await _offlineClock.read();
        await _store.saveDeviceContext(StoredDeviceContext(
          deviceId: bootstrap.deviceId,
          merchantId: bootstrap.merchantId,
          branchId: bootstrap.branchId,
          merchantName: bootstrap.merchantName,
          branchName: bootstrap.branchName,
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
          await _invalidateDeviceAuthorization();
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
            return PosGateSnapshot(
                state: PosGateState.offlineCredentialsExpired,
                recoveryMessage: operationErrorMessage(error));
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
    lockCashier();
    final oldDeviceId = _deviceId;
    await _deviceAuth.signOut();
    if (oldDeviceId != null) await _store.deleteForDevice(oldDeviceId);
    _deviceId = null;
  }

  Future<void> _invalidateDeviceAuthorization() async {
    lockCashier();
    final deviceId = _deviceId;
    if (deviceId != null) await _store.invalidateDeviceAuthorization(deviceId);
    try {
      await _deviceAuth.signOut();
    } on FirebaseAuthException {
      // Cached authorization is already gone even if local sign-out fails.
    }
  }

  CashierLoginService _loginService() {
    final id = _deviceId;
    if (id == null) throw StateError('This phone is not activated');
    return CashierLoginService(
        cashiers: _cashiers,
        store: _store,
        deviceId: id,
        clock: _clock,
        offlineClock: _offlineClock);
  }

  @override
  void lockCashier() => _activeSession = null;

  @override
  Future<void> invalidateCheckoutAuthorization(CashierSession session) async {
    if (!identical(_activeSession, session)) return;
    lockCashier();
    await _store.delete(session.deviceId, session.cashierId);
  }

  @override
  Future<IssuedCashierGrant?> readCheckoutGrant(
          String deviceId, String grantId) =>
      _store.readCheckoutGrant(deviceId, grantId);

  @override
  Future<CheckoutAuthorization> authorizeCheckout(
      CashierSession session) async {
    final id = _deviceId;
    final active = _activeSession;
    if (id == null ||
        !identical(active, session) ||
        session.deviceId != id ||
        _deviceAuth.currentUser?.uid != 'device:$id') {
      throw StateError('Sign in to continue checkout');
    }
    final context = await _store.readDeviceContext(id);
    final credential = await _store.read(id, session.cashierId);
    final grant = await _store.activeCheckoutGrant(id, session.cashierId);
    final now = _clock().toUtc();
    final reading = await _offlineClock.read();
    if (context == null ||
        credential == null ||
        grant == null ||
        grant.scope.merchantId != context.merchantId ||
        grant.scope.branchId != context.branchId ||
        grant.scope.credentialVersion != credential.credentialVersion ||
        !context.isUsableAt(OfflineTimeEvidence(
            now: now,
            lastObservedWallClock: context.lastObservedWallClock,
            anchor: context.clockAnchor,
            reading: reading)) ||
        !OfflineCredentialPolicy.isWithinTrustedWindow(
            issuedAt: credential.bundleIssuedAt,
            expiresAt: credential.bundleExpiresAt,
            time: OfflineTimeEvidence(
                now: now,
                lastObservedWallClock: credential.lastObservedWallClock,
                anchor: credential.clockAnchor,
                reading: reading)) ||
        !OfflineCredentialPolicy.isWithinTrustedWindow(
            issuedAt: grant.issuedAt,
            expiresAt: grant.expiresAt,
            time: OfflineTimeEvidence(
                now: now,
                lastObservedWallClock: credential.lastObservedWallClock,
                anchor: credential.clockAnchor,
                reading: reading))) {
      throw StateError('Reconnect and sign in to continue checkout');
    }
    // Recheck session after secure-storage/clock awaits, then persist time evidence.
    if (!identical(_activeSession, session) ||
        _deviceAuth.currentUser?.uid != 'device:$id') {
      throw StateError('Sign in to continue checkout');
    }
    await _store.save(credential.copyWith(lastObservedWallClock: now));
    await _store
        .saveDeviceContext(context.copyWith(lastObservedWallClock: now));
    if (!identical(_activeSession, session)) {
      throw StateError('Sign in to continue checkout');
    }
    return CheckoutAuthorization(
        scope: grant.scope,
        occurredAt: now,
        merchantName: context.merchantName ?? context.merchantId,
        branchName: context.branchName ?? context.branchId);
  }

  static bool _isNetworkError(String code) =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'network-request-failed';

  Future<void> _trySyncQueuedSecurityEvents() async {
    try {
      await _loginService().syncQueuedSecurityEvents();
    } on Object {
      // Sync failures, including malformed acknowledgements, retain pending
      // events and cannot undo successful bootstrap or online authentication.
    }
  }

  @override
  Future<CashierLoginResult> loginCashier(String cashierId, String pin) async {
    lockCashier();
    final service = _loginService();
    try {
      final result = await service.loginOnline(cashierId, pin);
      await _trySyncQueuedSecurityEvents();
      _activeSession = result.session;
      return result;
    } on FirebaseFunctionsException catch (error) {
      if (!_isNetworkError(error.code)) rethrow;
      final result = await service.loginOffline(cashierId, pin);
      _activeSession = result.session;
      return result;
    }
  }

  @override
  Future<CashierLoginResult> changePin(
      String cashierId, String currentPin, String newPin) async {
    lockCashier();
    await _cashiers.changePin(cashierId, currentPin, newPin);
    final result = await _loginService().loginOnline(cashierId, newPin);
    await _trySyncQueuedSecurityEvents();
    _activeSession = result.session;
    return result;
  }
}
