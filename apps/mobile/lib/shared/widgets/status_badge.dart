import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/cafe_theme_extension.dart';

enum StatusBadgeVariant { success, warning, error, information, neutral }

/// Accessible semantic badge combining color, text, and optional icon
/// to ensure status is distinguishable regardless of color perception.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.variant = StatusBadgeVariant.neutral,
    this.icon,
    this.isPill = false,
  });

  final String label;
  final StatusBadgeVariant variant;
  final IconData? icon;
  final bool isPill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cafeExt = CafeThemeExtension.of(context);

    Color bg;
    Color fg;
    BorderSide border;

    switch (variant) {
      case StatusBadgeVariant.success:
        bg = cafeExt.positiveSurface;
        fg = cafeExt.positiveOnSurface;
        border = BorderSide(color: fg.withValues(alpha: 0.3));
      case StatusBadgeVariant.warning:
        bg = cafeExt.warningSurface;
        fg = cafeExt.warningOnSurface;
        border = BorderSide(color: fg.withValues(alpha: 0.3));
      case StatusBadgeVariant.error:
        bg = cafeExt.errorSurface;
        fg = cafeExt.errorOnSurface;
        border = BorderSide(color: fg.withValues(alpha: 0.3));
      case StatusBadgeVariant.information:
        bg = cafeExt.infoSurface;
        fg = cafeExt.infoOnSurface;
        border = BorderSide(color: fg.withValues(alpha: 0.3));
      case StatusBadgeVariant.neutral:
        bg = theme.colorScheme.surface;
        fg = theme.colorScheme.onSurfaceVariant;
        border = BorderSide(color: theme.colorScheme.outline);
    }

    final borderRadius = isPill ? AppRadius.radiusPill : AppRadius.radiusSm;

    return Semantics(
      label: '$label status',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: borderRadius,
          border: Border.fromBorderSide(border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13.0, color: fg),
              AppSpacing.gapHorizontalXs,
            ],
            Text(
              label,
              style: AppTypography.small.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

