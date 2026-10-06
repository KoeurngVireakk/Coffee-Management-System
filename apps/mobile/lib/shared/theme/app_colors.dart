import 'package:flutter/material.dart';

/// Semantic and palette color tokens for the Premium Café OS design system.
///
/// Palette follows the 60-25-10-5 visual proportions:
/// - 60% Warm Cream / Light Surface
/// - 25% Espresso
/// - 10% Forest Green
/// - 5% Caramel Accent
abstract final class AppColors {
  // --- Core Brand Tokens (Light) ---
  static const Color espresso = Color(0xFF3A2618);
  static const Color forestGreen = Color(0xFF2F6B4F);
  static const Color caramel = Color(0xFFD68A3A);
  static const Color warmCream = Color(0xFFFAF7F2);
  static const Color white = Color(0xFFFFFFFF);
  static const Color latte = Color(0xFFF1E9E1);

  // --- Text & Neutral Tokens (Light) ---
  static const Color textPrimaryLight = Color(0xFF211A16);
  static const Color textSecondaryLight = Color(0xFF756A63);
  static const Color borderLight = Color(0xFFE5DDD5);
  static const Color borderSubtleLight = Color(0xFFEFE8E1);

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
  static const Color darkPrimaryWarm = Color(0xFFE1C3AD);
  static const Color darkSecondaryGreen = Color(0xFF8FC9A9);
  static const Color darkAccentCaramel = Color(0xFFE7AD72);

  // --- Text & Neutral Tokens (Dark) ---
  static const Color textPrimaryDark = Color(0xFFF5EFEA);
  static const Color textSecondaryDark = Color(0xFFC8BBB2);
  static const Color borderDark = Color(0xFF3B322D);
  static const Color borderSubtleDark = Color(0xFF2F2722);

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
