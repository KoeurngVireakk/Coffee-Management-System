import 'package:flutter/material.dart';

/// Typography definitions supporting English (Inter) and Khmer (Noto Sans Khmer)
/// with safe line heights to accommodate subscript consonants and diacritics.
abstract final class AppTypography {
  static const List<String> fontFallback = <String>[
    'Inter',
    'Noto Sans Khmer',
    'sans-serif',
  ];

  static const TextStyle display = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.5,
    fontFamilyFallback: fontFallback,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w700,
    height: 1.35,
    letterSpacing: -0.3,
    fontFamilyFallback: fontFallback,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.2,
    fontFamilyFallback: fontFallback,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamilyFallback: fontFallback,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamilyFallback: fontFallback,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    height: 1.45,
    fontFamilyFallback: fontFallback,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 1.45,
    fontFamilyFallback: fontFallback,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    height: 1.4,
    fontFamilyFallback: fontFallback,
  );

  static const TextStyle small = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
    fontFamilyFallback: fontFallback,
  );

  // --- Financial & Scannable Numeric Typography ---
  static const TextStyle price = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
    fontFamilyFallback: fontFallback,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle priceLarge = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    fontFamilyFallback: fontFallback,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle kpi = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w700,
    height: 1.25,
    fontFamilyFallback: fontFallback,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Generates a complete Material 3 TextTheme populated with our typography scale.
  static TextTheme createTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: display.copyWith(color: primaryColor),
      displayMedium: h1.copyWith(color: primaryColor),
      displaySmall: h2.copyWith(color: primaryColor),
      headlineMedium: h3.copyWith(color: primaryColor),
      titleLarge: title.copyWith(color: primaryColor),
      titleMedium: title.copyWith(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      titleSmall: label.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      bodyLarge: bodyLarge.copyWith(color: primaryColor),
      bodyMedium: body.copyWith(color: primaryColor),
      bodySmall: small.copyWith(color: secondaryColor),
      labelLarge: label.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      labelMedium: label.copyWith(color: secondaryColor),
      labelSmall: small.copyWith(color: secondaryColor),
    );
  }
}

