import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

class SariSupplyBrandShowcase extends StatelessWidget {
  const SariSupplyBrandShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: SariSupplyTheme.light,
      home: Scaffold(
        appBar: AppBar(title: const Text('SariSupply')),
        body: ListView(
          padding: const EdgeInsets.all(SariSupplySpacing.md),
          children: [
            const SsSectionHeader(title: 'Today'),
            const SizedBox(height: SariSupplySpacing.sm),
            const SsMetricCard(
              label: "Today's sales",
              value: '₱12,840.00',
              trailing: SsStatusChip(label: '+12%', status: SsStatus.success),
            ),
            const SizedBox(height: SariSupplySpacing.lg),
            const SsTextField(hintText: 'Search products, SKU, or barcode…'),
            const SizedBox(height: SariSupplySpacing.lg),
            SsPrimaryButton(label: 'Continue', onPressed: () {}),
            const SizedBox(height: SariSupplySpacing.sm),
            SsSecondaryButton(label: 'Cancel', onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
