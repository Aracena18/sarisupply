import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sqflite/sqflite.dart';
import '../features/delivery/data/delivery_database.dart';
import '../features/delivery/presentation/driver_home_screen.dart';

class DriverAppGate extends StatefulWidget {
  const DriverAppGate({super.key, required this.auth, required this.gateway});
  final AuthRepository auth;
  final DeliveryFunctions gateway;
  @override
  State<DriverAppGate> createState() => _DriverAppGateState();
}

class _DriverAppGateState extends State<DriverAppGate> {
  StreamSubscription<AuthUser?>? _subscription;
  AuthUser? _user;
  InventoryStore? _store;
  List<Map<String, Object?>> _workspaces = [];
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
    });
    try {
      final workspaces = user == null
          ? <Map<String, Object?>>[]
          : await _assignments(user.uid);
      if (generation != _generation || !mounted) return;
      _workspaces = workspaces;
      if (_workspaces.length == 1) await _open(_workspaces.single, generation);
    } catch (error) {
      if (mounted && generation == _generation) {
        _error = operationErrorMessage(error);
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
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

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    unawaited(_store?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    return Scaffold(
        body: SariSupplyEntry(
            role: 'Driver',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    SariSupplyStatus(message: _error!, error: true),
                  if (!_busy && _user == null)
                    FilledButton(
                        onPressed: _authenticate,
                        child: const Text('Sign in with Google')),
                  if (!_busy && _user != null) ...[
                    if (_workspaces.isEmpty)
                      const Text(
                          'No assigned delivery workspace. Ask your store owner to assign you.'),
                    for (final workspace in _workspaces)
                      FilledButton(
                          onPressed: () => _choose(workspace),
                          child: Text(workspace['driverName'] as String)),
                    TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: _user!.uid));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Driver access ID copied. Share it with your store owner.')));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy driver access ID')),
                    TextButton(
                        onPressed: _load,
                        child: const Text('Refresh assignments')),
                    TextButton(
                        onPressed: () => _authenticate(signOut: true),
                        child: const Text('Sign out')),
                  ],
                ])));
  }
}
