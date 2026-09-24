import 'package:flutter/material.dart';

abstract final class SariSupplyTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }
}
