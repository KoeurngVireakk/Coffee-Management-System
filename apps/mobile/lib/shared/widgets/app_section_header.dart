import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Section header displaying title, optional subtitle, and optional trailing action.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  AppSpacing.gapVerticalXs,
                  Text(
                    subtitle!,
                    style: AppTypography.body.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[AppSpacing.gapHorizontalMd, action!],
        ],
      ),
    );
  }
}

