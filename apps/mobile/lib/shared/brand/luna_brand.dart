import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Owner-selected artwork from design/Luna_Cafe_Vector_Logo_Kit.
/// Supplied raster equivalents preserve geometry; no reconstruction is needed.
abstract final class LunaBrand {
  static const name = 'Luna Cafe';
  static const stackedLogo = 'assets/branding/logo_stacked_transparent.png';
  static const darkMark = 'assets/branding/monogram_gold.png';
  static const lightMark = 'assets/branding/monogram_espresso.png';
}

/// Decorative supplied monogram beside an accessible textual shop name.
class LunaBrandMark extends StatelessWidget {
  const LunaBrandMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    Theme.of(context).brightness == Brightness.dark
        ? LunaBrand.darkMark
        : LunaBrand.lightMark,
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
    filterQuality: FilterQuality.medium,
  );
}

/// The kit's outlined stacked wordmark needs no branding font.
class LunaBrandLockup extends StatelessWidget {
  const LunaBrandLockup({super.key});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).height * .27).clamp(140.0, 240.0);
    return Center(
      child: Container(
        width: width,
        padding: AppSpacing.edgeInsetsMd,
        decoration: BoxDecoration(
          color: AppColors.coffeeBrown,
          borderRadius: AppRadius.radiusXxl,
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? AppShadows.cardRestingDark
              : AppShadows.cardRestingLight,
        ),
        child: AspectRatio(
          aspectRatio: 1200 / 1390,
          child: Image.asset(
            LunaBrand.stackedLogo,
            fit: BoxFit.contain,
            semanticLabel: LunaBrand.name,
            cacheWidth:
                ((width - 2 * AppSpacing.md) *
                        MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// Compact headers use readable native text where a full lockup cannot fit.
class LunaWordmark extends StatelessWidget {
  const LunaWordmark({super.key, this.fontSize = 20});
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text(
    LunaBrand.name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AppTypography.title.copyWith(
      fontSize: fontSize,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}
