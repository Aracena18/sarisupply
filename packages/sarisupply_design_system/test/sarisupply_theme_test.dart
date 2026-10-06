import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  test('creates a Material 3 light theme', () {
    final theme = SariSupplyTheme.light();

    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, const Color(0xFF00796B));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAF7));
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
    expect(theme.textTheme.bodyLarge?.fontFamily,
        'packages/sarisupply_design_system/NunitoSans');
  });
}
