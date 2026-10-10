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
      primaryContainer: SariSupplyColors.orange100,
      onPrimaryContainer: SariSupplyColors.ink950,
      secondaryContainer: SariSupplyColors.orange50,
      onSecondaryContainer: SariSupplyColors.ink950,
      tertiary: SariSupplyColors.ink800,
      onTertiary: SariSupplyColors.card,
      tertiaryContainer: SariSupplyColors.ink50,
      onTertiaryContainer: SariSupplyColors.ink950,
      surface: SariSupplyColors.card,
      onSurface: SariSupplyColors.ink950,
      error: SariSupplyColors.error,
      onError: SariSupplyColors.card,
      errorContainer: SariSupplyColors.error.withValues(alpha: 0.1),
      onErrorContainer: SariSupplyColors.error,
      outline: SariSupplyColors.ink500,
      outlineVariant: SariSupplyColors.divider,
      onSurfaceVariant: SariSupplyColors.ink600,
      surfaceTint: Colors.transparent,
      inverseSurface: SariSupplyColors.ink800,
      onInverseSurface: SariSupplyColors.paper,
      inversePrimary: SariSupplyColors.orange200,
      surfaceContainerLowest: SariSupplyColors.card,
      surfaceContainerLow: SariSupplyColors.paper,
      surfaceContainer: SariSupplyColors.canvas,
      surfaceContainerHigh: SariSupplyColors.ink50,
      surfaceContainerHighest: SariSupplyColors.ink50,
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
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: SariSupplyColors.paper,
        foregroundColor: SariSupplyColors.ink950,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: SariSupplyTypography.fontFamily,
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: SariSupplyColors.ink950,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? SariSupplyColors.ink50
                : SariSupplyColors.orange500,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? SariSupplyColors.ink500
                : SariSupplyColors.ink950,
          ),
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
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? SariSupplyColors.ink500
                : SariSupplyColors.orange700,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? SariSupplyColors.divider
                  : SariSupplyColors.orange700,
            ),
          ),
          textStyle: const WidgetStatePropertyAll(SariSupplyTypography.label),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SariSupplyRadii.md),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: SariSupplyColors.orange700,
          disabledForegroundColor: SariSupplyColors.ink500,
          textStyle: SariSupplyTypography.label,
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: WidgetStatePropertyAll(SariSupplyColors.ink600),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SariSupplyColors.orange700,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: SariSupplyColors.orange700,
        unselectedLabelColor: SariSupplyColors.ink600,
        indicatorColor: SariSupplyColors.orange700,
        dividerColor: SariSupplyColors.divider,
        labelStyle: SariSupplyTypography.label,
        unselectedLabelStyle: SariSupplyTypography.label,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SariSupplyColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SariSupplyRadii.lg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SariSupplyColors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SariSupplyColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: SariSupplyTypography.body.copyWith(
          color: SariSupplyColors.ink500,
        ),
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
          borderSide: const BorderSide(
            color: SariSupplyColors.orange700,
            width: 2,
          ),
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
      primaryContainer: SariSupplyColors.orange700,
      onPrimaryContainer: SariSupplyColors.card,
      secondaryContainer: SariSupplyColors.ink800,
      onSecondaryContainer: SariSupplyColors.paper,
      tertiary: SariSupplyColors.ink300,
      onTertiary: SariSupplyColors.ink950,
      tertiaryContainer: SariSupplyColors.ink800,
      onTertiaryContainer: SariSupplyColors.paper,
      surface: SariSupplyColors.ink900,
      onSurface: SariSupplyColors.paper,
      error: SariSupplyColors.error,
      onError: SariSupplyColors.card,
      errorContainer: SariSupplyColors.error.withValues(alpha: 0.2),
      onErrorContainer: SariSupplyColors.paper,
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
