import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Reusable card surface embodying the Premium Café OS aesthetic:
/// crisp subtle border, gentle surface color, generous whitespace,
/// and optional micro-elevation.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.edgeInsetsLg,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.elevation = 0.0,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final double elevation;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBg = backgroundColor ?? theme.colorScheme.surface;
    final effectiveBorder = borderColor ?? theme.colorScheme.outline;
    final effectiveRadius = borderRadius ?? AppRadius.radiusXl;

    List<BoxShadow>? effectiveShadow = boxShadow;
    if (effectiveShadow == null && elevation > 0) {
      if (elevation <= 1.0) {
        effectiveShadow = isDark
            ? AppShadows.cardRestingDark
            : AppShadows.cardRestingLight;
      } else {
        effectiveShadow = isDark
            ? AppShadows.cardElevatedDark
            : AppShadows.cardElevatedLight;
      }
    }

    final content = Padding(padding: padding, child: child);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: Border.all(color: effectiveBorder, width: 1.0),
        boxShadow: effectiveShadow,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Material(
          color: Colors.transparent,
          child: onTap != null
              ? InkWell(
                  onTap: onTap,
                  borderRadius: effectiveRadius,
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}
