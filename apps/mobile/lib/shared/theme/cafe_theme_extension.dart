import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic color extension for café-specific UI states that fall outside
/// standard Material 3 ColorScheme tokens.
@immutable
class CafeThemeExtension extends ThemeExtension<CafeThemeExtension> {
  const CafeThemeExtension({
    required this.positiveSurface,
    required this.positiveOnSurface,
    required this.warningSurface,
    required this.warningOnSurface,
    required this.errorSurface,
    required this.errorOnSurface,
    required this.infoSurface,
    required this.infoOnSurface,
    required this.borderSubtle,
    required this.surfaceElevated,
    required this.accentCaramel,
    required this.onAccentCaramel,
    required this.priceColor,
  });

  final Color positiveSurface;
  final Color positiveOnSurface;
  final Color warningSurface;
  final Color warningOnSurface;
  final Color errorSurface;
  final Color errorOnSurface;
  final Color infoSurface;
  final Color infoOnSurface;
  final Color borderSubtle;
  final Color surfaceElevated;
  final Color accentCaramel;
  final Color onAccentCaramel;
  final Color priceColor;

  static const CafeThemeExtension light = CafeThemeExtension(
    positiveSurface: AppColors.successSurfaceLight,
    positiveOnSurface: AppColors.successLight,
    warningSurface: AppColors.warningSurfaceLight,
    warningOnSurface: AppColors.warningLight,
    errorSurface: AppColors.errorSurfaceLight,
    errorOnSurface: AppColors.errorLight,
    infoSurface: AppColors.infoSurfaceLight,
    infoOnSurface: AppColors.infoLight,
    borderSubtle: AppColors.borderSubtleLight,
    surfaceElevated: AppColors.white,
    accentCaramel: AppColors.caramel,
    onAccentCaramel: AppColors.textPrimaryLight,
    priceColor: AppColors.espresso,
  );

  static const CafeThemeExtension dark = CafeThemeExtension(
    positiveSurface: AppColors.successSurfaceDark,
    positiveOnSurface: AppColors.successDark,
    warningSurface: AppColors.warningSurfaceDark,
    warningOnSurface: AppColors.warningDark,
    errorSurface: AppColors.errorSurfaceDark,
    errorOnSurface: AppColors.errorDark,
    infoSurface: AppColors.infoSurfaceDark,
    infoOnSurface: AppColors.infoDark,
    borderSubtle: AppColors.borderSubtleDark,
    surfaceElevated: AppColors.darkElevated,
    accentCaramel: AppColors.darkAccentCaramel,
    onAccentCaramel: AppColors.textPrimaryLight,
    priceColor: AppColors.darkPrimaryWarm,
  );

  @override
  CafeThemeExtension copyWith({
    Color? positiveSurface,
    Color? positiveOnSurface,
    Color? warningSurface,
    Color? warningOnSurface,
    Color? errorSurface,
    Color? errorOnSurface,
    Color? infoSurface,
    Color? infoOnSurface,
    Color? borderSubtle,
    Color? surfaceElevated,
    Color? accentCaramel,
    Color? onAccentCaramel,
    Color? priceColor,
  }) {
    return CafeThemeExtension(
      positiveSurface: positiveSurface ?? this.positiveSurface,
      positiveOnSurface: positiveOnSurface ?? this.positiveOnSurface,
      warningSurface: warningSurface ?? this.warningSurface,
      warningOnSurface: warningOnSurface ?? this.warningOnSurface,
      errorSurface: errorSurface ?? this.errorSurface,
      errorOnSurface: errorOnSurface ?? this.errorOnSurface,
      infoSurface: infoSurface ?? this.infoSurface,
      infoOnSurface: infoOnSurface ?? this.infoOnSurface,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      accentCaramel: accentCaramel ?? this.accentCaramel,
      onAccentCaramel: onAccentCaramel ?? this.onAccentCaramel,
      priceColor: priceColor ?? this.priceColor,
    );
  }

  @override
  CafeThemeExtension lerp(
    covariant ThemeExtension<CafeThemeExtension>? other,
    double t,
  ) {
    if (other is! CafeThemeExtension) return this;
    return CafeThemeExtension(
      positiveSurface:
          Color.lerp(positiveSurface, other.positiveSurface, t) ??
          positiveSurface,
      positiveOnSurface:
          Color.lerp(positiveOnSurface, other.positiveOnSurface, t) ??
          positiveOnSurface,
      warningSurface:
          Color.lerp(warningSurface, other.warningSurface, t) ?? warningSurface,
      warningOnSurface:
          Color.lerp(warningOnSurface, other.warningOnSurface, t) ??
          warningOnSurface,
      errorSurface:
          Color.lerp(errorSurface, other.errorSurface, t) ?? errorSurface,
      errorOnSurface:
          Color.lerp(errorOnSurface, other.errorOnSurface, t) ?? errorOnSurface,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t) ?? infoSurface,
      infoOnSurface:
          Color.lerp(infoOnSurface, other.infoOnSurface, t) ?? infoOnSurface,
      borderSubtle:
          Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t) ??
          surfaceElevated,
      accentCaramel:
          Color.lerp(accentCaramel, other.accentCaramel, t) ?? accentCaramel,
      onAccentCaramel:
          Color.lerp(onAccentCaramel, other.onAccentCaramel, t) ??
          onAccentCaramel,
      priceColor: Color.lerp(priceColor, other.priceColor, t) ?? priceColor,
    );
  }

  static CafeThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<CafeThemeExtension>() ?? light;
  }
}
