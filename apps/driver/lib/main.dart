import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import 'bootstrap/driver_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initializeHuman(
    selectDriverFirebaseOptions(const String.fromEnvironment('SARISUPPLY_ENV')),
  );
  runApp(const ProviderScope(child: SariSupplyDriverApp()));
}

class SariSupplyDriverApp extends StatelessWidget {
  const SariSupplyDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppIdentity.driverName,
      theme: SariSupplyTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppIdentity.driverName),
              Text('Foundation ready'),
            ],
          ),
        ),
      ),
    );
  }
}
