import 'package:flutter/material.dart';
import '../tokens/typography.dart';
import 'ss_card.dart';

class SsMetricCard extends StatelessWidget {
  const SsMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SariSupplyTypography.caption),
                const SizedBox(height: 6),
                Text(value, style: SariSupplyTypography.moneyLarge),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
