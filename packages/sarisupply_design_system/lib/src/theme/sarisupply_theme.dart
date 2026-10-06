import 'package:flutter/material.dart';

abstract final class SariSupplyTheme {
  static const primary = Color(0xFF00796B);
  static const mango = Color(0xFFFFCA58);
  static const background = Color(0xFFFAFAF7);
  static const ink = Color(0xFF173C36);
  static const spacing = <double>[4, 8, 12, 16, 24, 32];

  static ThemeData light() {
    const text = ink;
    final colors = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      secondary: mango,
      onSecondary: text,
      surface: background,
      onSurface: text,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: 'packages/sarisupply_design_system/NunitoSans',
    );
    const radius = BorderRadius.all(Radius.circular(12));
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius)),
    );
    return base.copyWith(
      scaffoldBackgroundColor: colors.surface,
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 14),
        titleLarge: base.textTheme.titleLarge
            ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: base.textTheme.titleMedium
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: text,
        titleTextStyle: base.textTheme.titleLarge
            ?.copyWith(color: text, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderRadius: radius),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      iconButtonTheme: const IconButtonThemeData(
          style:
              ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48)))),
      cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)))),
    );
  }
}
