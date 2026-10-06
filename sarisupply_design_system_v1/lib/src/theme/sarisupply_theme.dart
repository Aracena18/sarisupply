import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';
import '../tokens/typography.dart';

abstract final class SariSupplyTheme {
  static ThemeData get light {
    final scheme = ColorScheme.light(
      primary: SariSupplyColors.orange500,
      onPrimary: SariSupplyColors.ink950,
      secondary: SariSupplyColors.orange700,
      onSecondary: SariSupplyColors.card,
      surface: SariSupplyColors.card,
      onSurface: SariSupplyColors.ink950,
      error: SariSupplyColors.error,
      onError: SariSupplyColors.card,
      outline: SariSupplyColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: SariSupplyColors.paper,
      fontFamily: SariSupplyTypography.fontFamily,
      textTheme: SariSupplyTypography.textTheme,
      dividerColor: SariSupplyColors.divider,
      cardColor: SariSupplyColors.card,
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          backgroundColor:
              const WidgetStatePropertyAll(SariSupplyColors.orange500),
          foregroundColor:
              const WidgetStatePropertyAll(SariSupplyColors.ink950),
          textStyle: const WidgetStatePropertyAll(SariSupplyTypography.label),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SariSupplyRadii.md),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor:
              const WidgetStatePropertyAll(SariSupplyColors.orange700),
          side: const WidgetStatePropertyAll(
            BorderSide(color: SariSupplyColors.orange500),
          ),
          textStyle: const WidgetStatePropertyAll(SariSupplyTypography.label),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SariSupplyRadii.md),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SariSupplyColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle:
            SariSupplyTypography.body.copyWith(color: SariSupplyColors.ink300),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SariSupplyRadii.md),
          borderSide: const BorderSide(color: SariSupplyColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SariSupplyRadii.md),
          borderSide: const BorderSide(color: SariSupplyColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SariSupplyRadii.md),
          borderSide:
              const BorderSide(color: SariSupplyColors.orange500, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: SariSupplyColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SariSupplyRadii.md),
          side: const BorderSide(color: SariSupplyColors.divider),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SariSupplyColors.card,
        indicatorColor: SariSupplyColors.orange100,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => SariSupplyTypography.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? SariSupplyColors.orange700
                : SariSupplyColors.ink600,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.dark(
      primary: SariSupplyColors.orange400,
      onPrimary: SariSupplyColors.ink950,
      secondary: SariSupplyColors.orange200,
      onSecondary: SariSupplyColors.ink950,
      surface: SariSupplyColors.ink900,
      onSurface: SariSupplyColors.paper,
      error: SariSupplyColors.error,
      onError: SariSupplyColors.card,
      outline: SariSupplyColors.ink800,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: SariSupplyColors.ink950,
      fontFamily: SariSupplyTypography.fontFamily,
      textTheme: SariSupplyTypography.textTheme.apply(
        bodyColor: SariSupplyColors.paper,
        displayColor: SariSupplyColors.paper,
      ),
    );
  }
}
