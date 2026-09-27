import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import 'bootstrap/pos_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initializeHuman(
    selectPosFirebaseOptions(const String.fromEnvironment('SARISUPPLY_ENV')),
  );
  runApp(const ProviderScope(child: SariSupplyPosApp()));
}

class SariSupplyPosApp extends StatelessWidget {
  const SariSupplyPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppIdentity.posName,
      theme: SariSupplyTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppIdentity.posName),
              Text('Foundation ready'),
            ],
          ),
        ),
      ),
    );
  }
}
