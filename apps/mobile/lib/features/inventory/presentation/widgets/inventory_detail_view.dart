import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radius.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/theme/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/inventory_item.dart';
import '../inventory_controller.dart';
import 'inventory_item_form_dialog.dart';
import 'stock_movement_dialog.dart';
import 'stock_movement_history_view.dart';

/// Reusable master-detail inspector for single inventory item details and stock actions.
class InventoryDetailView extends StatelessWidget {
  const InventoryDetailView({
    super.key,
    required this.item,
    required this.controller,
    required this.canAdjustInventory,
  });

  final InventoryItem item;
  final InventoryController controller;
  final bool canAdjustInventory;

  void _openMovementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StockMovementDialog(item: item, controller: controller),
    );
  }

  void _openHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          title: Text('${item.name} Movements'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        body: StockMovementHistoryView(item: item, controller: controller),
      ),
    );
  }

  void _openEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) =>
          InventoryItemFormDialog(item: item, controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final currentItem = controller.selectedItem?.id == item.id
            ? controller.selectedItem!
            : item;
        final isBusy = controller.isLoadingItem;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Card: Name, SKU, Unit, Badges ---
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentItem.name,
                                style: AppTypography.h3.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              AppSpacing.gapVerticalXs,
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: AppRadius.radiusXs,
                                    ),
                                    child: Text(
                                      'SKU: ${currentItem.sku}',
                                      style: AppTypography.small.copyWith(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Base Unit: ${currentItem.baseUnit.label} (${currentItem.baseUnit.value})',
                                    style: AppTypography.small.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isBusy)
                          const AppLoadingIndicator(size: 20)
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'Refresh item',
                            onPressed: () => controller.refreshSelectedItem(),
                          ),
                      ],
                    ),
                    AppSpacing.gapVerticalMd,

                    // Status Badges
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (currentItem.lowStock)
                          const StatusBadge(
                            label: 'Low Stock',
                            variant: StatusBadgeVariant.warning,
                            icon: Icons.warning_amber_rounded,
                          ),
                        if (!currentItem.isActive)
                          const StatusBadge(
                            label: 'Retired',
                            variant: StatusBadgeVariant.neutral,
                            icon: Icons.archive_outlined,
                          ),
                        if (currentItem.isActive && !currentItem.lowStock)
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
              AppSpacing.gapVerticalMd,

              // --- Stock Balances Card ---
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Balances',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    AppSpacing.gapVerticalMd,

                    // Available balance highlight
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: currentItem.lowStock
                            ? AppColors.warningLight.withValues(alpha: 0.12)
                            : theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available Stock',
                                style: AppTypography.small.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              AppSpacing.gapVerticalXs,
                              Text(
                                currentItem.available.formatWithUnit(
                                  currentItem.baseUnit.value,
                                ),
                                style: AppTypography.h3.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: currentItem.lowStock
                                      ? AppColors.warningDark
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            currentItem.lowStock
                                ? Icons.warning_amber_rounded
                                : Icons.inventory_2_rounded,
                            size: 32,
                            color: currentItem.lowStock
                                ? AppColors.warningDark
                                : theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapVerticalMd,

                    // Details grid: On Hand, Reserved, Reorder Level
                    Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.md,
                      children: [
                        _buildBalanceMetric(
                          context,
                          label: 'On Hand',
                          value: currentItem.onHand.formatWithUnit(
                            currentItem.baseUnit.value,
                          ),
                        ),
                        _buildBalanceMetric(
                          context,
                          label: 'Reserved (in active cart/order)',
                          value: currentItem.reserved.formatWithUnit(
                            currentItem.baseUnit.value,
                          ),
                        ),
                        _buildBalanceMetric(
                          context,
                          label: 'Reorder Threshold',
                          value: currentItem.reorderLevel.formatWithUnit(
                            currentItem.baseUnit.value,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.gapVerticalMd,

              // --- Actions (Permission-Gated) ---
              if (canAdjustInventory) ...[
                Text(
                  'Inventory Actions',
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapVerticalSm,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppButton(
                      label: 'Record Stock Movement',
                      variant: AppButtonVariant.primary,
                      leadingIcon: Icons.swap_horiz_rounded,
                      onPressed: () => _openMovementDialog(context),
                    ),
                    AppButton(
                      label: 'Movement History',
                      variant: AppButtonVariant.outline,
                      leadingIcon: Icons.history_rounded,
                      onPressed: () => _openHistorySheet(context),
                    ),
                    AppButton(
                      label: 'Edit Item',
                      variant: AppButtonVariant.secondary,
                      leadingIcon: Icons.edit_outlined,
                      onPressed: () => _openEditDialog(context),
                    ),
                  ],
                ),
                AppSpacing.gapVerticalMd,
              ],

              // --- Metadata Footer: Timestamps ---
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  if (currentItem.createdAt != null)
                    Text(
                      'Created: ${Formatters.formatDateTime(currentItem.createdAt!)}',
                      style: AppTypography.small.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (currentItem.updatedAt != null)
                    Text(
                      'Updated: ${Formatters.formatDateTime(currentItem.updatedAt!)}',
                      style: AppTypography.small.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceMetric(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.small.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapVerticalXs,
        Text(
          value,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
