import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'cafe_theme_extension.dart';

/// Central theme factory providing configured Material 3 light and dark themes.
abstract final class AppTheme {
  /// Builds the Premium Café OS light theme.
  static ThemeData buildLightTheme() {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.espresso,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.latte,
      onPrimaryContainer: AppColors.espresso,
      secondary: AppColors.forestGreen,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.successSurfaceLight,
      onSecondaryContainer: AppColors.forestGreen,
      tertiary: AppColors.caramel,
      onTertiary: AppColors.textPrimaryLight,
      tertiaryContainer: AppColors.warningSurfaceLight,
      onTertiaryContainer: AppColors.warningLight,
      error: AppColors.errorLight,
      onError: AppColors.white,
      errorContainer: AppColors.errorSurfaceLight,
      onErrorContainer: AppColors.errorLight,
      surface: AppColors.white,
      onSurface: AppColors.textPrimaryLight,
      onSurfaceVariant: AppColors.textSecondaryLight,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.borderSubtleLight,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.warmCream,
      extension: CafeThemeExtension.light,
      primaryText: AppColors.textPrimaryLight,
      secondaryText: AppColors.textSecondaryLight,
      borderColor: AppColors.borderLight,
      isDark: false,
    );
  }

  /// Builds the Premium Café OS dark theme.
  static ThemeData buildDarkTheme() {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.darkPrimaryWarm,
      onPrimary: AppColors.darkBackground,
      primaryContainer: AppColors.darkElevated,
      onPrimaryContainer: AppColors.darkPrimaryWarm,
      secondary: AppColors.darkSecondaryGreen,
      onSecondary: AppColors.darkBackground,
      secondaryContainer: AppColors.successSurfaceDark,
      onSecondaryContainer: AppColors.darkSecondaryGreen,
      tertiary: AppColors.darkAccentCaramel,
      onTertiary: AppColors.darkBackground,
      tertiaryContainer: AppColors.warningSurfaceDark,
      onTertiaryContainer: AppColors.darkAccentCaramel,
      error: AppColors.errorDark,
      onError: AppColors.darkBackground,
      errorContainer: AppColors.errorSurfaceDark,
      onErrorContainer: AppColors.errorDark,
      surface: AppColors.darkSurface,
      onSurface: AppColors.textPrimaryDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderSubtleDark,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.darkBackground,
      extension: CafeThemeExtension.dark,
      primaryText: AppColors.textPrimaryDark,
      secondaryText: AppColors.textSecondaryDark,
      borderColor: AppColors.borderDark,
      isDark: true,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required CafeThemeExtension extension,
    required Color primaryText,
    required Color secondaryText,
    required Color borderColor,
    required bool isDark,
  }) {
    final textTheme = AppTypography.createTextTheme(primaryText, secondaryText);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[extension],

      // --- AppBar Theme ---
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: primaryText,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: AppTypography.title.copyWith(color: primaryText),
      ),

      // --- Card Theme ---
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusXl,
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),

      // --- Input Decoration Theme ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        hintStyle: AppTypography.body.copyWith(color: secondaryText),
        labelStyle: AppTypography.body.copyWith(color: secondaryText),
        helperStyle: AppTypography.small.copyWith(color: secondaryText),
        errorStyle: AppTypography.small.copyWith(color: colorScheme.error),
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),

      // --- Elevated Button Theme ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(AppSpacing.huge, AppSpacing.minTouchTarget),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // --- Outlined Button Theme ---
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSpacing.huge, AppSpacing.minTouchTarget),
          foregroundColor: primaryText,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // --- Text Button Theme ---
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSpacing.huge, AppSpacing.minTouchTarget),
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // --- Dialog Theme ---
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),
      ),

      // --- Divider Theme ---
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

