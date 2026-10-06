import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Reusable card surface embodying the Premium Café OS aesthetic:
/// crisp subtle border, gentle surface color, and generous whitespace.
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBg = backgroundColor ?? theme.colorScheme.surface;
    final effectiveBorder = borderColor ?? theme.colorScheme.outline;
    final effectiveRadius = borderRadius ?? AppRadius.radiusXl;

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: Border.all(color: effectiveBorder, width: 1.0),
      ),
      child: ClipRRect(borderRadius: effectiveRadius, child: content),
    );
  }
}
