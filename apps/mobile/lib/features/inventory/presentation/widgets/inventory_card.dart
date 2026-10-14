import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radius.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/inventory_item.dart';

/// Accessible inventory list card displaying current stock levels and status.
///
/// Built with [LayoutBuilder] and [Wrap] to ensure zero pixel overflow under
/// 2.0x text scaling.
class InventoryCard extends StatelessWidget {
  const InventoryCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isSelected = false,
  });

  final InventoryItem item;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            minHeight: AppSpacing.minTouchTarget,
          ),
          child: AppCard(
            onTap: onTap,
            elevation: isSelected ? 2.0 : (item.lowStock ? 1.0 : 0.0),
            borderColor: isSelected
                ? theme.colorScheme.primary
                : (item.lowStock
                    ? AppColors.warningLight.withValues(alpha: 0.5)
                    : null),
            backgroundColor: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                : null,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Semantics(
              button: true,
              label:
                  'Inventory item ${item.name}, SKU ${item.sku}, available ${item.available.toFormattedString()} ${item.baseUnit.value}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Header: Name & SKU ---
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth - 32,
                        ),
                        child: Text(
                          item.name,
                          style: AppTypography.title.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs + 2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: AppRadius.radiusXs,
                        ),
                        child: Text(
                          item.sku,
                          style: AppTypography.small.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalSm,

                  // --- Primary Balance: Available Quantity ---
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    children: [
                      Text(
                        'Available:',
                        style: AppTypography.small.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        item.available.formatWithUnit(item.baseUnit.value),
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: item.lowStock
                              ? AppColors.warningDark
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalXs,

                  // --- Secondary Details: Reserved & Reorder ---
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (item.reserved.isPositive)
                        Text(
                          'Reserved: ${item.reserved.formatWithUnit(item.baseUnit.value)}',
                          style: AppTypography.small.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      if (item.reorderLevel.isPositive)
                        Text(
                          'Reorder: ${item.reorderLevel.formatWithUnit(item.baseUnit.value)}',
                          style: AppTypography.small.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  AppSpacing.gapVerticalSm,

                  // --- Status Badges ---
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (item.lowStock)
                        const StatusBadge(
                          label: 'Low Stock',
                          variant: StatusBadgeVariant.warning,
                          icon: Icons.warning_amber_rounded,
                        ),
                      if (!item.isActive)
                        const StatusBadge(
                          label: 'Retired',
                          variant: StatusBadgeVariant.neutral,
                          icon: Icons.archive_outlined,
                        ),
                      if (item.isActive && !item.lowStock)
                        const StatusBadge(
                          label: 'In Stock',
                          variant: StatusBadgeVariant.success,
                          icon: Icons.check_circle_outline,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
