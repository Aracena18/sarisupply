import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../sarisupply_design_system.dart';

/// The approved SariSupply symbol for compact product headers.
class SariSupplySymbol extends StatelessWidget {
  const SariSupplySymbol({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'SariSupply symbol',
    image: true,
    child: SvgPicture.asset(
      'assets/brand/sarisupply_symbol.svg',
      package: 'sarisupply_design_system',
      width: size,
      height: size,
      excludeFromSemantics: true,
    ),
  );
}

class SariSupplyBrand extends StatelessWidget {
  const SariSupplyBrand({super.key, required this.role});
  final String role;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        label: 'SariSupply symbol',
        image: true,
        child: SvgPicture.asset(
          'assets/brand/sarisupply_symbol.svg',
          package: 'sarisupply_design_system',
          width: 136,
          excludeFromSemantics: true,
        ),
      ),
      const SizedBox(height: SariSupplySpacing.xs),
      Text('SariSupply', style: SariSupplyTypography.screenTitle),
      const SizedBox(height: SariSupplySpacing.xs),
      Text(
        role,
        style: SariSupplyTypography.body.copyWith(
          color: SariSupplyColors.ink600,
        ),
      ),
    ],
  );
}

/// Compact horizontal identity for product app bars and workspace headers.
class SariSupplyBrandLockup extends StatelessWidget {
  const SariSupplyBrandLockup({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SvgPicture.asset(
        'assets/brand/sarisupply_symbol.svg',
        package: 'sarisupply_design_system',
        width: 36,
        excludeFromSemantics: true,
      ),
      const SizedBox(width: SariSupplySpacing.sm),
      Text(
        'SariSupply',
        style: SariSupplyTypography.cardHeading.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// Shared entry layout, including loading and recovery states.
class SariSupplyEntry extends StatelessWidget {
  const SariSupplyEntry({super.key, required this.role, required this.child});
  final String role;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(SariSupplySpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SariSupplyBrand(role: role),
                    const SizedBox(height: SariSupplySpacing.xl),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
