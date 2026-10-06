import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import 'app/firebase_pos_workflow.dart';
import 'app/pos_app_gate.dart';
import 'bootstrap/pos_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(
      child: SariSupplyStartupGate(
    role: 'POS',
    initialize: () async {
      final options = selectPosFirebaseOptions(
          const String.fromEnvironment('SARISUPPLY_ENV', defaultValue: 'dev'));
      await FirebaseBootstrap.initializeHuman(options);
      await FirebaseBootstrap.initializeDevice(options);
    },
    child: const SariSupplyPosApp(),
  )));
}

class SariSupplyPosApp extends StatelessWidget {
  const SariSupplyPosApp({super.key, this.workflow});

  final PosWorkflow? workflow;

  @override
  Widget build(BuildContext context) {
    Widget home;
    try {
      home = PosAppGate(workflow: workflow ?? FirebasePosWorkflow());
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'SariSupply POS startup',
      ));
      home = const Scaffold(
        body: SariSupplyEntry(
          role: 'POS',
          child: SariSupplyStatus(
            message: 'POS setup is incomplete. Contact your administrator.',
            error: true,
          ),
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppIdentity.posName,
      theme: SariSupplyTheme.light(),
      home: home,
    );
  }
}
