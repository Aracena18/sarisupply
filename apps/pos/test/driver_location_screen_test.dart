import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_pos/features/inventory/presentation/driver_location_screen.dart';

class FakeLocations implements DriverLocationGateway {
  DriverLocationSnapshot? snapshot;
  @override
  Future<DriverLocationSnapshot?> readDriverLocation(
          String merchantId, String runId) async =>
      snapshot;
  @override
  Future<void> pauseDriverLocation(
      String merchantId, String runId, int eventAtMs) async {}
  @override
  Future<DriverLocationSnapshot> updateDriverLocation(String merchantId,
          String runId, DriverLocationFix fix, int eventAtMs) async =>
      throw UnimplementedError();
}

const run = {
  'id': 'run',
  'driverName': 'Driver',
  'vehicleInfo': 'Van',
  'stops': [
    {
      'sequence': 1,
      'destinationName': 'Store',
      'destinationAddress': 'Davao City'
    }
  ]
};
void main() {
  testWidgets(
      'phone layout renders empty location and route stops without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light,
        home: DriverLocationScreen(
            merchantId: 'merchant', run: run, gateway: FakeLocations())));
    await tester.pump();
    expect(find.text('No shared location yet'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'stale GPS stays last known, with maps action and capture timestamp',
      (tester) async {
    final old = DateTime.now().subtract(const Duration(minutes: 3));
    final gateway = FakeLocations()
      ..snapshot = DriverLocationSnapshot(
          runId: 'run',
          driverId: 'driver',
          fix: DriverLocationFix(
              latitude: 7.1,
              longitude: 125.6,
              accuracyMeters: 20,
              capturedAt: old),
          receivedAt: old,
          sharing: true);
    await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light,
        home: DriverLocationScreen(
            merchantId: 'merchant', run: run, gateway: gateway)));
    await tester.pump();
    expect(find.text('Last known location'), findsOneWidget);
    expect(find.text('Open in Maps'), findsOneWidget);
    expect(find.textContaining('Captured:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
