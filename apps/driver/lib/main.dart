import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

import 'bootstrap/driver_bootstrap.dart';
import 'app/driver_app_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(
      child: SariSupplyStartupGate(
    role: 'Driver',
    initialize: () async {
      await FirebaseBootstrap.initializeHuman(selectDriverFirebaseOptions(
          const String.fromEnvironment('SARISUPPLY_ENV', defaultValue: 'dev')));
    },
    child: const SariSupplyDriverApp(),
  )));
}

class SariSupplyDriverApp extends StatelessWidget {
  const SariSupplyDriverApp({super.key, this.auth, this.gateway});
  final AuthRepository? auth;
  final DeliveryFunctions? gateway;
  @override
  Widget build(BuildContext context) {
    Widget home;
    try {
      home = DriverAppGate(
          auth: auth ?? FirebaseGoogleAuthRepository.forDefaultApp(),
          gateway: gateway ?? DeliveryFunctions.forHuman(),
          authorization: AuthorizationWorkspaceFunctions.forDefaultApp());
    } catch (_) {
      home = const Scaffold(
          body: SariSupplyEntry(
              role: 'Driver',
              child: SariSupplyStatus(
                  message:
                      'Driver setup is incomplete. Contact your administrator.',
                  error: true)));
    }
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppIdentity.driverName,
        theme: SariSupplyTheme.light,
        home: home);
  }
}
