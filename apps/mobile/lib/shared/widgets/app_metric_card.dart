import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
import 'status_badge.dart';

/// High-impact metric card for displaying key performance indicators (KPIs).
///
/// Features tabular numeric figures to avoid layout jitter when values update,
/// optional trend or status badge, icon accent, and accessible semantic labeling.
class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.badgeLabel,
    this.badgeVariant = StatusBadgeVariant.success,
    this.onTap,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final String? badgeLabel;
  final StatusBadgeVariant badgeVariant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      elevation: 1.0,
      padding: AppSpacing.edgeInsetsLg,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                AppSpacing.gapHorizontalSm,
                Icon(
                  icon,
                  size: 20.0,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
          AppSpacing.gapVerticalSm,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.price.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 26.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeLabel != null) ...[
                AppSpacing.gapHorizontalMd,
                StatusBadge(
                  label: badgeLabel!,
                  variant: badgeVariant,
                  isPill: true,
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            AppSpacing.gapVerticalXs,
            Text(
              subtitle!,
              style: AppTypography.small.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

