import 'dart:async';
import 'package:sarisupply_driver/features/delivery/data/driver_gps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_driver/features/delivery/presentation/driver_location_controller.dart';

class FakeLocations implements DriverLocationGateway {
  final updates = <int>[];
  final pauses = <int>[];
  Object? failure;
  Completer<DriverLocationSnapshot>? delayed;
  @override
  Future<DriverLocationSnapshot> updateDriverLocation(String merchantId,
      String runId, DriverLocationFix fix, int eventAtMs) async {
    updates.add(eventAtMs);
    if (failure != null) throw failure!;
    if (delayed != null) return delayed!.future;
    return DriverLocationSnapshot(
        runId: runId,
        driverId: 'driver',
        fix: fix,
        receivedAt: DateTime.now(),
        sharing: true);
  }

  @override
  Future<void> pauseDriverLocation(
          String merchantId, String runId, int eventAtMs) async =>
      pauses.add(eventAtMs);
  @override
  Future<DriverLocationSnapshot?> readDriverLocation(
          String merchantId, String runId) async =>
      null;
}

DriverLocationFix fix() => DriverLocationFix(
    latitude: 7,
    longitude: 125,
    accuracyMeters: 10,
    capturedAt: DateTime.now());
void main() {
  test('stop fences upload and prevents future samples', () async {
    final gateway = FakeLocations();
    final c = DriverLocationController(
        gateway: gateway, merchantId: 'merchant', capture: () async => fix());
    addTearDown(c.dispose);
    c.selectRun('run');
    await c.start();
    expect(c.lastSuccessful?.runId, 'run');
    c.stop();
    await c.updateNow();
    expect(gateway.updates.length, 1);
    expect(gateway.pauses.single, greaterThan(gateway.updates.single));
    expect(c.enabled, false);
  });
  test('background during capture discards fix; return captures fresh',
      () async {
    final gateway = FakeLocations(), capture = Completer<DriverLocationFix>();
    var captures = 0;
    final c = DriverLocationController(
        gateway: gateway,
        merchantId: 'merchant',
        capture: () {
          captures++;
          return captures == 1 ? capture.future : Future.value(fix());
        });
    addTearDown(c.dispose);
    c.selectRun('run');
    final start = c.start();
    c.setForeground(false);
    capture.complete(fix());
    await start;
    expect(gateway.updates, isEmpty);
    c.setForeground(true);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.updates.length, 1);
  });
  test('late response cannot restore success after stop', () async {
    final gateway = FakeLocations()
      ..delayed = Completer<DriverLocationSnapshot>();
    final c = DriverLocationController(
        gateway: gateway, merchantId: 'merchant', capture: () async => fix());
    addTearDown(c.dispose);
    c.selectRun('run');
    final start = c.start();
    await Future<void>.delayed(Duration.zero);
    c.stop();
    gateway.delayed!.complete(DriverLocationSnapshot(
        runId: 'run',
        driverId: 'driver',
        fix: fix(),
        receivedAt: DateTime.now(),
        sharing: true));
    await start;
    expect(c.lastSuccessful, isNull);
    expect(gateway.pauses.single, greaterThan(gateway.updates.single));
  });
  test('revocation stops automatic sharing', () async {
    final gateway = FakeLocations();
    final c = DriverLocationController(
        gateway: gateway, merchantId: 'merchant', capture: () async => fix());
    addTearDown(c.dispose);
    c.selectRun('run');
    await c.start();
    gateway.failure =
        FirebaseException(plugin: 'functions', code: 'permission-denied');
    await c.updateNow();
    expect(c.enabled, false);
    expect(c.lastSuccessful, isNotNull);
    expect(c.error, contains('access'));
  });
  test('connection failure retains last success; retry captures fresh sample',
      () async {
    final gateway = FakeLocations();
    var captures = 0;
    final c = DriverLocationController(
        gateway: gateway,
        merchantId: 'merchant',
        capture: () async {
          captures++;
          return fix();
        });
    addTearDown(c.dispose);
    c.selectRun('run');
    await c.start();
    final last = c.lastSuccessful;
    gateway.failure =
        FirebaseException(plugin: 'functions', code: 'unavailable');
    await c.updateNow();
    expect(c.lastSuccessful, same(last));
    expect(c.enabled, true);
    gateway.failure = null;
    await c.updateNow();
    expect(captures, 3);
    expect(c.error, isNull);
    expect(c.lastSuccessful, isNot(same(last)));
  });
  test('run change stops sharing and clears old location', () async {
    final gateway = FakeLocations();
    final c = DriverLocationController(
        gateway: gateway, merchantId: 'merchant', capture: () async => fix());
    addTearDown(c.dispose);
    c.selectRun('run');
    await c.start();
    c.selectRun('other');
    expect(c.enabled, false);
    expect(c.lastSuccessful, isNull);
    expect(gateway.pauses, hasLength(1));
  });
  test('permission denial stops sharing without uploading a position',
      () async {
    final gateway = FakeLocations();
    final c = DriverLocationController(
        gateway: gateway,
        merchantId: 'merchant',
        capture: () async => throw const LocationCaptureException(
            'Location permission is needed.'));
    addTearDown(c.dispose);
    c.selectRun('run');
    await c.start();
    expect(c.enabled, false);
    expect(gateway.updates, isEmpty);
    expect(c.error, contains('permission'));
    expect(c.lastSuccessful, isNull);
  });
  test('return during an old upload captures a fresh fix immediately afterward',
      () async {
    final pending = Completer<DriverLocationSnapshot>();
    final gateway = FakeLocations()..delayed = pending;
    final c = DriverLocationController(
        gateway: gateway, merchantId: 'merchant', capture: () async => fix());
    addTearDown(c.dispose);
    c.selectRun('run');
    final start = c.start();
    await Future<void>.delayed(Duration.zero);
    c.setForeground(false);
    c.setForeground(true);
    gateway.delayed = null;
    pending.complete(DriverLocationSnapshot(
        runId: 'run',
        driverId: 'driver',
        fix: fix(),
        receivedAt: DateTime.now(),
        sharing: true));
    await start;
    await Future<void>.delayed(Duration.zero);
    expect(gateway.updates.length, 2);
    expect(gateway.updates.last, greaterThan(gateway.pauses.single));
    expect(c.lastSuccessful, isNotNull);
  });
}
