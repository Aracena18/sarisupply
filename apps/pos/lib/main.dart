import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
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
