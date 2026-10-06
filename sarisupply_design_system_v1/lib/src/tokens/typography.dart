import 'dart:ui';
import 'package:flutter/material.dart';
import 'colors.dart';

abstract final class SariSupplyTypography {
  static const fontFamily = 'InstrumentSans';
  static const fallback = <String>['Inter', 'Roboto', 'Arial'];

  static const _base = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    color: SariSupplyColors.ink950,
  );

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
    displaySmall: display,
    headlineMedium: screenTitle,
    headlineSmall: sectionHeading,
    titleMedium: cardHeading,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    labelLarge: label,
    bodySmall: caption,
  );
}
