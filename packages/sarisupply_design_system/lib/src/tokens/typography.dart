import 'package:flutter/material.dart';
import 'colors.dart';

abstract final class SariSupplyTypography {
  static const fontFamily = 'packages/sarisupply_design_system/InstrumentSans';
  static const fallback = <String>[
    'packages/sarisupply_design_system/Inter',
    'Roboto',
    'Arial',
  ];

  static const display = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    color: SariSupplyColors.ink950,
  );

  static const screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    color: SariSupplyColors.ink950,
  );

  static const sectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    color: SariSupplyColors.ink950,
  );

  static const cardHeading = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    color: SariSupplyColors.ink950,
  );

  static const bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: SariSupplyColors.ink950,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: SariSupplyColors.ink950,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w600,
    color: SariSupplyColors.ink950,
  );

  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: SariSupplyColors.ink600,
  );

  static const moneyLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w700,
    color: SariSupplyColors.ink950,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const textTheme = TextTheme(
    displayLarge: display,
    displayMedium: screenTitle,
    displaySmall: sectionHeading,
    headlineLarge: screenTitle,
    headlineMedium: sectionHeading,
    headlineSmall: cardHeading,
    titleLarge: cardHeading,
    titleMedium: cardHeading,
    titleSmall: label,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: label,
    labelMedium: label,
    labelSmall: caption,
  );
}
