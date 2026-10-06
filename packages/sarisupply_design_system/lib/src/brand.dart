import 'package:flutter/material.dart';
import 'page_content.dart';

class SariSupplyBrand extends StatelessWidget {
  const SariSupplyBrand({super.key, required this.role});
  final String role;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/brand/storefront.png',
              package: 'sarisupply_design_system',
              width: 96,
              height: 96,
              excludeFromSemantics: true),
          const SizedBox(height: 12),
          Text('SariSupply',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 24)),
          const SizedBox(height: 4),
          Text(role, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

/// Shared entry layout, including loading and recovery states.
class SariSupplyEntry extends StatelessWidget {
  const SariSupplyEntry({super.key, required this.role, required this.child});
  final String role;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
      child: SariSupplyPageContent(
          maxWidth: 440,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                SariSupplyBrand(role: role),
                const SizedBox(height: 32),
                child,
              ])));
}
