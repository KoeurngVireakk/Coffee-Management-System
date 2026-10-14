import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/theme/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/inventory_item.dart';
import '../../domain/stock_movement.dart';
import '../inventory_controller.dart';

/// Read-only ledger view displaying paginated historical stock movements for an item.
class StockMovementHistoryView extends StatefulWidget {
  const StockMovementHistoryView({
    super.key,
    required this.item,
    required this.controller,
  });

  final InventoryItem item;
  final InventoryController controller;

  @override
  State<StockMovementHistoryView> createState() =>
      _StockMovementHistoryViewState();
}

class _StockMovementHistoryViewState extends State<StockMovementHistoryView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.loadMovements();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoadingMovements && controller.movements.isEmpty) {
          return const Center(
            child: AppLoadingIndicator(message: 'Loading movement history...'),
          );
        }

        final failure = controller.movementsFailure;
        if (failure != null && controller.movements.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  AppSpacing.gapVerticalMd,
                  Text(
                    failure.message,
                    textAlign: TextAlign.center,
                    style: AppTypography.body,
                  ),
                  AppSpacing.gapVerticalMd,
                  AppButton(
                    label: 'Retry',
                    onPressed: () => controller.loadMovements(),
                  ),
                ],
              ),
            ),
          );
        }

        final movements = controller.movements;
        if (movements.isEmpty) {
          return const Center(
            child: AppEmptyState(
              icon: Icons.history_rounded,
              title: 'No Movements Yet',
              description: 'This item has no recorded stock movements.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: movements.length + (controller.hasMoreMovements ? 1 : 0),
          separatorBuilder: (_, _) => AppSpacing.gapVerticalSm,
          itemBuilder: (context, index) {
            if (index == movements.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: controller.isLoadingMovements
                      ? const AppLoadingIndicator(size: 24)
                      : AppButton(
                          label: 'Load More Movements',
                          variant: AppButtonVariant.outline,
                          onPressed: () => controller.loadMoreMovements(),
                        ),
                ),
              );
            }

            final movement = movements[index];
            final isPositive = movement.quantityDelta.isPositive;

            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header: Delta & Reason Badge ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${isPositive ? '+' : ''}${movement.quantityDelta.toFormattedString()} ${widget.item.baseUnit.value}',
                        style: AppTypography.title.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isPositive
                              ? AppColors.successLight
                              : AppColors.errorLight,
                        ),
                      ),
                      _buildReasonBadge(movement.reason),
                    ],
                  ),
                  AppSpacing.gapVerticalXs,

                  // --- Note (if present) ---
                  if (movement.note != null && movement.note!.isNotEmpty) ...[
                    Text(
                      movement.note!,
                      style: AppTypography.body.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    AppSpacing.gapVerticalXs,
                  ],

                  // --- Metadata Footer: Timestamp & IDs ---
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (movement.createdAt != null)
                        Text(
                          Formatters.formatDateTime(movement.createdAt!),
                          style: AppTypography.small.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (movement.orderId != null)
                        Text(
                          'Order #${movement.orderId}',
                          style: AppTypography.small.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (movement.actorId != null)
                        Text(
                          'Staff #${movement.actorId}',
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
      },
    );
  }

  Widget _buildReasonBadge(StockMovementReason reason) {
    switch (reason) {
      case StockMovementReason.openingBalance:
        return const StatusBadge(
          label: 'Opening Balance',
          variant: StatusBadgeVariant.information,
        );
      case StockMovementReason.receipt:
        return const StatusBadge(
          label: 'Receipt',
          variant: StatusBadgeVariant.success,
        );
      case StockMovementReason.waste:
        return const StatusBadge(
          label: 'Waste',
          variant: StatusBadgeVariant.error,
        );
      case StockMovementReason.adjustment:
        return const StatusBadge(
          label: 'Adjustment',
          variant: StatusBadgeVariant.warning,
        );
      case StockMovementReason.sale:
        return const StatusBadge(
          label: 'Sale',
          variant: StatusBadgeVariant.neutral,
        );
    }
  }
}
