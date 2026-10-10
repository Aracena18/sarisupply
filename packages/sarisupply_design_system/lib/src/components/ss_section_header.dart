import 'package:flutter/material.dart';
import '../tokens/typography.dart';

class SsSectionHeader extends StatelessWidget {
  const SsSectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: SariSupplyTypography.sectionHeading),
        ),
        if (action != null) action!,
      ],
    );
  }
}
