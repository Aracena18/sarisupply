import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';
import '../tokens/typography.dart';

enum SsStatus { success, warning, error, info, neutral }

class SsStatusChip extends StatelessWidget {
  const SsStatusChip({
    super.key,
    required this.label,
    this.status = SsStatus.neutral,
  });

  final String label;
  final SsStatus status;

  Color get _color => switch (status) {
    SsStatus.success => SariSupplyColors.success,
    SsStatus.warning => SariSupplyColors.warning,
    SsStatus.error => SariSupplyColors.error,
    SsStatus.info => SariSupplyColors.info,
    SsStatus.neutral => SariSupplyColors.ink600,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SariSupplyRadii.xl),
      ),
      child: Text(
        label,
        style: SariSupplyTypography.caption.copyWith(
          color: _color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
