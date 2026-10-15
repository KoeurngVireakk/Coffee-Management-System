import 'package:flutter/material.dart';

/// Luna Cafe palette within the existing Material 3 design system.
/// Antique gold is decorative; strong gold is safe for foreground accents.
/// Functional success/warning/error/info tokens stay distinct from branding.
abstract final class AppColors {
  // --- Core Brand Tokens (Light) ---
  static const Color coffeeBrown = Color(0xFF2B1B0F);
  static const Color espressoBrown = Color(0xFF4B3626);
  static const Color antiqueGold = Color(0xFFC9A96A);
  static const Color strongGold = Color(0xFF806127);
  static const Color warmBeige = Color(0xFFDCCEB7);
  static const Color espresso = coffeeBrown;
  static const Color forestGreen = Color(0xFF2F6B4F);
  static const Color caramel = strongGold;
  static const Color warmCream = Color(0xFFF8F3EA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color latte = Color(0xFFF0E6D6);

  // --- Text & Neutral Tokens (Light) ---
  static const Color textPrimaryLight = coffeeBrown;
  static const Color textSecondaryLight = Color(0xFF756A63);
  static const Color borderLight = Color(0xFFE5DDD5);
  static const Color borderSubtleLight = Color(0xFFEFE8E1);

  // --- Surface Hierarchy Tokens (Light) ---
  static const Color surfaceLowestLight = Color(0xFFFFFFFF);
  static const Color surfaceLowLight = warmCream;
  static const Color surfaceLightDefault = warmCream;
  static const Color surfaceHighLight = latte;
  static const Color surfaceHighestLight = Color(0xFFE8DDD2);

  // --- Functional Status Tokens (Light) ---
  static const Color successLight = Color(0xFF2E7D32);
  static const Color successSurfaceLight = Color(0xFFEDF7ED);
  static const Color warningLight = Color(0xFFA05A00);
  static const Color warningSurfaceLight = Color(0xFFFFF4E5);
  static const Color errorLight = Color(0xFFB3261E);
  static const Color errorSurfaceLight = Color(0xFFFDE8E8);
  static const Color infoLight = Color(0xFF2563EB);
  static const Color infoSurfaceLight = Color(0xFFEFF6FF);

  // --- Core Brand Tokens (Dark) ---
  static const Color darkBackground = Color(0xFF171311);
  static const Color darkSurface = Color(0xFF211B18);
  static const Color darkElevated = Color(0xFF2A231F);
  static const Color darkPrimaryWarm = Color(0xFFF8F3EA);
  static const Color darkSecondaryGreen = Color(0xFF8FC9A9);
  static const Color darkAccentCaramel = antiqueGold;

  // --- Text & Neutral Tokens (Dark) ---
  static const Color textPrimaryDark = Color(0xFFF5EFEA);
  static const Color textSecondaryDark = Color(0xFFC8BBB2);
  static const Color borderDark = Color(0xFF3B322D);
  static const Color borderSubtleDark = Color(0xFF2F2722);

  // --- Surface Hierarchy Tokens (Dark) ---
  static const Color surfaceLowestDark = Color(0xFF14100E);
  static const Color surfaceLowDark = Color(0xFF1B1614);
  static const Color surfaceDarkDefault = Color(0xFF211B18);
  static const Color surfaceHighDark = Color(0xFF2A231F);
  static const Color surfaceHighestDark = Color(0xFF362D28);

  // --- Functional Status Tokens (Dark) ---
  static const Color successDark = Color(0xFF81C784);
  static const Color successSurfaceDark = Color(0xFF1B2F1F);
  static const Color warningDark = Color(0xFFFFB74D);
  static const Color warningSurfaceDark = Color(0xFF33230E);
  static const Color errorDark = Color(0xFFE57373);
  static const Color errorSurfaceDark = Color(0xFF351918);
  static const Color infoDark = Color(0xFF64B5F6);
  static const Color infoSurfaceDark = Color(0xFF102847);
}
