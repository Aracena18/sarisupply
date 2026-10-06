import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

import 'app/admin_app_gate.dart';
import 'bootstrap/admin_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(
      child: SariSupplyStartupGate(
    role: 'Admin',
    initialize: () async {
      await FirebaseBootstrap.initializeHuman(selectAdminFirebaseOptions(
          const String.fromEnvironment('SARISUPPLY_ENV', defaultValue: 'dev')));
    },
    child: const SariSupplyAdminApp(),
  )));
}

class SariSupplyAdminApp extends StatelessWidget {
  const SariSupplyAdminApp({super.key, this.auth, this.access, this.reviews});

  final AuthRepository? auth;
  final AdminAccessRepository? access;
  final AdminReviewRepository? reviews;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppIdentity.adminName,
      theme: SariSupplyTheme.light(),
      home: AdminAppGate(auth: auth, access: access, reviews: reviews),
    );
  }
}
