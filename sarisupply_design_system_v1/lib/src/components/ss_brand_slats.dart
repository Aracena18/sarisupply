import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../tokens/colors.dart';

class SsBrandSlats extends StatelessWidget {
  const SsBrandSlats({
    super.key,
    this.width = 180,
    this.opacity = 0.06,
    this.color = SariSupplyColors.orange500,
  });

  final double width;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SvgPicture.asset(
        'assets/elements/slats_pattern.svg',
        package: 'sarisupply_design_system',
        width: width,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
