import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  test('spacing scale remains ordered', () {
    expect(SariSupplySpacing.xxs < SariSupplySpacing.xs, isTrue);
    expect(SariSupplySpacing.xs < SariSupplySpacing.sm, isTrue);
    expect(SariSupplySpacing.sm < SariSupplySpacing.md, isTrue);
    expect(SariSupplySpacing.md < SariSupplySpacing.lg, isTrue);
  });

  test('default card radius is 12', () {
    expect(SariSupplyRadii.md, 12);
  });
}
