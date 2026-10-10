import 'package:sarisupply_company/sarisupply_company.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import '../features/delivery/data/delivery_database.dart';
import '../features/delivery/presentation/driver_home_screen.dart';
import 'driver_access_view.dart';

class DriverAppGate extends StatefulWidget {
  const DriverAppGate(
      {super.key,
      required this.auth,
      required this.gateway,
      this.authorization});
  final AuthRepository auth;
  final DeliveryFunctions gateway;
  final AuthorizationWorkspaceFunctions? authorization;
  @override
  State<DriverAppGate> createState() => _DriverAppGateState();
}

class _DriverAppGateState extends State<DriverAppGate> {
  static const _uuid = Uuid();
  final Map<String, String> _invitationOperationIds = {};
  StreamSubscription<AuthUser?>? _subscription;
  AuthUser? _user;
  InventoryStore? _store;
  List<Map<String, Object?>> _workspaces = [];
  List<AuthorizationWorkspace> _companyWorkspaces = [];
  List<CompanyInvitation> _invitations = [];
  AuthorizationWorkspace? _selectedCompany;
  String? _companyAccessError;
  bool _acceptingInvite = false;
  Map<String, Object?>? _workspace;
  bool _busy = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _subscription = widget.auth.authStateChanges().listen((user) {
      _user = user;
      _load();
    }, onError: (Object error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = operationErrorMessage(error);
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> _assignments(String uid) async {
    final root = await getDatabasesPath();
    final cache = await openDatabase('$root/driver-access.db',
        version: 1,
        onCreate: (db, _) => db.execute(
            'CREATE TABLE assignments(uid TEXT PRIMARY KEY,body TEXT NOT NULL,boot INTEGER,elapsed INTEGER,wall INTEGER)'));
    try {
      Map<String, Object?>? clock;
      try {
        clock = await const MethodChannel('sarisupply/offline_clock')
            .invokeMapMethod<String, Object?>('read');
      } on Object {/* Missing clock disables offline recovery. */}
      try {
        final assignments = await widget.gateway.workspaces();
        await cache.insert(
            'assignments',
            {
              'uid': uid,
              'body': jsonEncode(assignments),
              'boot': clock?['bootCount'],
              'elapsed': clock?['elapsedRealtimeMs'],
              'wall': DateTime.now().millisecondsSinceEpoch
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
        return assignments;
      } on Object catch (error) {
        if (!isRetryableOperationError(error)) {
          await cache.delete('assignments', where: 'uid=?', whereArgs: [uid]);
          rethrow;
        }
        final rows =
            await cache.query('assignments', where: 'uid=?', whereArgs: [uid]);
        if (rows.isEmpty || clock == null) rethrow;
        final cached = rows.single;
        final elapsed = clock['elapsedRealtimeMs'];
        if (cached['boot'] != clock['bootCount'] ||
            elapsed is! int ||
            cached['elapsed'] is! int ||
            elapsed < (cached['elapsed'] as int) ||
            elapsed - (cached['elapsed'] as int) >=
                const Duration(days: 7).inMilliseconds ||
            DateTime.now().millisecondsSinceEpoch < (cached['wall'] as int)) {
          rethrow;
        }
        return (jsonDecode(cached['body'] as String) as List)
            .map((r) => Map<String, Object?>.from(r as Map))
            .toList();
      }
    } finally {
      await cache.close();
    }
  }

  Future<List<AuthorizationWorkspace>> _companyAssignments(String uid) async {
    final root = await getDatabasesPath();
    final cache = await openDatabase('$root/driver-company-access.db',
        version: 1,
        onCreate: (db, _) => db.execute(
            'CREATE TABLE assignments(uid TEXT PRIMARY KEY,body TEXT NOT NULL,boot INTEGER,elapsed INTEGER,wall INTEGER)'));
    try {
      Map<String, Object?>? clock;
      try {
        clock = await const MethodChannel('sarisupply/offline_clock')
            .invokeMapMethod<String, Object?>('read');
      } catch (_) {}
      try {
        final page = await widget.authorization!
            .getAuthorizationWorkspaces(pageSize: 50);
        final body = page.workspaces
            .map((w) => {
                  ...w.context,
                  'displayName': w.displayName,
                  'membershipRevision': w.membershipRevision,
                  'roleGrantRevision': w.roleGrantRevision,
                  'scope': {
                    'kind': w.scope.kind,
                    if (w.scope.kind == 'warehouses')
                      'warehouseIds': w.scope.warehouseIds
                  }
                })
            .toList();
        await cache.insert(
            'assignments',
            {
              'uid': uid,
              'body': jsonEncode(body),
              'boot': clock?['bootCount'],
              'elapsed': clock?['elapsedRealtimeMs'],
              'wall': DateTime.now().millisecondsSinceEpoch
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
        return page.workspaces;
      } catch (error) {
        if (!isRetryableOperationError(error)) {
          await cache.delete('assignments', where: 'uid=?', whereArgs: [uid]);
          rethrow;
        }
        final rows =
            await cache.query('assignments', where: 'uid=?', whereArgs: [uid]);
        if (rows.isEmpty ||
            clock == null ||
            clock['bootCount'] is! int ||
            clock['elapsedRealtimeMs'] is! int) {
          rethrow;
        }
        final row = rows.single;
        final elapsed = clock['elapsedRealtimeMs'] as int;
        if (row['boot'] != clock['bootCount'] ||
            row['elapsed'] is! int ||
            elapsed < (row['elapsed'] as int) ||
            elapsed - (row['elapsed'] as int) >=
                const Duration(days: 7).inMilliseconds ||
            DateTime.now().millisecondsSinceEpoch < (row['wall'] as int)) {
          rethrow;
        }
        return (jsonDecode(row['body'] as String) as List)
            .map(AuthorizationWorkspace.fromMap)
            .toList();
      }
    } finally {
      await cache.close();
    }
  }

  Future<void> _load() async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    final generation = ++_generation;
    final user = _user;
    final previous = _store;
    _store = null;
    await previous?.close();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _workspace = null;
      _workspaces = [];
      _companyWorkspaces = [];
      _invitations = [];
      _selectedCompany = null;
      _companyAccessError = null;
    });
    var workspaces = <Map<String, Object?>>[];
    String? legacyAccessError;
    if (user != null) {
      try {
        workspaces = await _assignments(user.uid);
      } catch (error) {
        legacyAccessError = operationErrorMessage(error);
      }
    }
    var companyWorkspaces = <AuthorizationWorkspace>[];
    var invitations = <CompanyInvitation>[];
    String? companyAccessError;
    if (user != null && widget.authorization != null) {
      try {
        companyWorkspaces = await _companyAssignments(user.uid);
        invitations = await widget.authorization!.listMyInvitations();
      } catch (error) {
        companyAccessError = operationErrorMessage(error);
      }
    }
    if (generation != _generation || !mounted) return;
    _workspaces = workspaces;
    _error =
        workspaces.isEmpty && companyWorkspaces.isEmpty && invitations.isEmpty
            ? legacyAccessError
            : null;
    _companyWorkspaces = companyWorkspaces;
    _invitations = invitations;
    _companyAccessError = companyAccessError;
    if (_workspaces.length == 1 &&
        _companyWorkspaces.isEmpty &&
        _invitations.isEmpty) {
      try {
        await _open(_workspaces.single, generation);
      } catch (error) {
        _error = operationErrorMessage(error);
      }
    }
    if (mounted && generation == _generation) setState(() => _busy = false);
  }

  Future<void> _open(Map<String, Object?> workspace, int generation) async {
    final store = await openDriverInventory(
        merchantId: workspace['merchantId'] as String,
        branchId: workspace['warehouseId'] as String);
    if (!mounted || generation != _generation) {
      await store.close();
      return;
    }
    setState(() {
      _store = store;
      _workspace = workspace;
    });
  }

  Future<void> _choose(Map<String, Object?> workspace) async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _open(workspace, generation);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = operationErrorMessage(error));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _authenticate({bool signOut = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final generation = _generation;
    try {
      if (signOut) {
        await widget.auth.signOut();
      } else {
        await widget.auth.signInWithGoogle();
      }
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _accept(CompanyInvitation invitation) async {
    if (_acceptingInvite || widget.authorization == null) return;
    setState(() {
      _acceptingInvite = true;
      _companyAccessError = null;
    });
    try {
      final operationId =
          _invitationOperationIds.putIfAbsent(invitation.id, () => _uuid.v4());
      await widget.authorization!.acceptInvitation(invitation, operationId);
      _invitationOperationIds.remove(invitation.id);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _companyAccessError = operationErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _acceptingInvite = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    unawaited(_store?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_busy && _selectedCompany != null && _user != null) {
      final selected = _selectedCompany!;
      return CompanyOperationsScreen(
        key: ValueKey(
            '${selected.companyId}:${selected.role.wireValue}:${selected.membershipRevision}:${selected.roleGrantRevision}'),
        authorizationRevision:
            '${selected.membershipRevision}:${selected.roleGrantRevision}',
        companyId: selected.companyId,
        title: selected.displayName,
        context: selected.context,
        onSignOut: () => _authenticate(signOut: true),
        onExit: () => setState(() => _selectedCompany = null),
      );
    }
    if (!_busy && _store != null && _workspace != null && _user != null) {
      return DriverHomeScreen(
          key: ValueKey('${_user!.uid}:${_workspace!['merchantId']}'),
          store: _store!,
          merchantId: _workspace!['merchantId'] as String,
          driverId: _user!.uid,
          driverName: _workspace!['driverName'] as String,
          deliveryGateway: widget.gateway,
          onSignOut: () => _authenticate(signOut: true));
    }
    if (_user != null) {
      return DriverAccessView(
        workspaces: _companyWorkspaces,
        invitations: _invitations,
        legacyWorkspaces: _workspaces,
        loading: _busy,
        acceptingInvitation: _acceptingInvite,
        error: _error,
        companyError: _companyAccessError,
        onWorkspace: (workspace) =>
            setState(() => _selectedCompany = workspace),
        onLegacyWorkspace: _choose,
        onAccept: _accept,
        onRefresh: _load,
        onSignOut: () => _authenticate(signOut: true),
      );
    }
    return Scaffold(
      body: SariSupplyEntry(
        role: 'Driver',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) SariSupplyStatus(message: _error!, error: true),
            if (!_busy)
              FilledButton(
                onPressed: _authenticate,
                child: const Text('Sign in with Google'),
              ),
          ],
        ),
      ),
    );
  }
}
