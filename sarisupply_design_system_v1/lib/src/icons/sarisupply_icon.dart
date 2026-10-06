import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../tokens/colors.dart';

enum SariSupplyIconName {
  pos,
  products,
  inventory,
  restock,
  orders,
  suppliers,
  driver,
  branches,
  analytics,
  cashier,
}

class SariSupplyIcon extends StatelessWidget {
  const SariSupplyIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color = SariSupplyColors.ink950,
  });

  final SariSupplyIconName name;
  final double size;
  final Color color;

  String get _asset =>
      'assets/icons/${name.name}.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _asset,
      package: 'sarisupply_design_system',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
