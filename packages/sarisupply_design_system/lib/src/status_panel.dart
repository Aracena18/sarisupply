import 'package:flutter/material.dart';
import '../sarisupply_design_system.dart';

/// Text and icon distinguish status without relying on color alone.
class SariSupplyStatus extends StatelessWidget {
  const SariSupplyStatus({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.error = false,
    this.actions = const [],
  });
  final String message;
  final IconData icon;
  final bool error;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(SariSupplySpacing.md),
      decoration: BoxDecoration(
        color: error
            ? SariSupplyColors.error.withValues(alpha: 0.1)
            : SariSupplyColors.ink50,
        borderRadius: BorderRadius.circular(SariSupplyRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: error ? SariSupplyColors.error : SariSupplyColors.ink600,
              ),
              const SizedBox(width: SariSupplySpacing.sm),
              Expanded(child: Text(message, style: SariSupplyTypography.body)),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: SariSupplySpacing.xs),
            Wrap(
              spacing: SariSupplySpacing.xs,
              runSpacing: SariSupplySpacing.xs,
              children: actions,
            ),
          ],
        ],
      ),
    ),
  );
}
