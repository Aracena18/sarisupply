import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  runApp(const ProviderScope(child: SariSupplyAdminApp()));
}

class SariSupplyAdminApp extends StatelessWidget {
  const SariSupplyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppIdentity.adminName,
      theme: SariSupplyTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppIdentity.adminName),
              Text('Foundation ready'),
            ],
          ),
        ),
      ),
    );
  }
}
