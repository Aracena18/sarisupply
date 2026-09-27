import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import 'app/firebase_pos_workflow.dart';
import 'app/pos_app_gate.dart';
import 'bootstrap/pos_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final options =
      selectPosFirebaseOptions(const String.fromEnvironment('SARISUPPLY_ENV'));
  await FirebaseBootstrap.initializeHuman(options);
  await FirebaseBootstrap.initializeDevice(options);
  runApp(const ProviderScope(child: SariSupplyPosApp()));
}

class SariSupplyPosApp extends StatelessWidget {
  const SariSupplyPosApp({super.key, this.workflow});

  final PosWorkflow? workflow;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppIdentity.posName,
      theme: SariSupplyTheme.light(),
      home: PosAppGate(workflow: workflow ?? FirebasePosWorkflow()),
    );
  }
}
