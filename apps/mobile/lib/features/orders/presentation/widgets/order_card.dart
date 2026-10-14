import 'package:flutter/material.dart';

import '../../../../shared/theme/app_radius.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/theme/cafe_theme_extension.dart';
import '../../../../shared/theme/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../pos/domain/order.dart';

/// Card widget displaying an order summary in the order history list.
///
/// Features high contrast, accessible touch targets (≥48dp), clear textual
/// status badges, and screen reader announcements.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.isSelected = false,
  });

  final Order order;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cafeExt = CafeThemeExtension.of(context);

    final statusVariant = switch (order.status) {
      OrderStatus.paid => StatusBadgeVariant.success,
      OrderStatus.pendingPayment => StatusBadgeVariant.warning,
      OrderStatus.cancelled => StatusBadgeVariant.neutral,
      OrderStatus.expired => StatusBadgeVariant.error,
    };

    final statusText = switch (order.status) {
      OrderStatus.paid => 'Paid',
      OrderStatus.pendingPayment => 'Pending Payment',
      OrderStatus.cancelled => 'Cancelled',
      OrderStatus.expired => 'Expired',
    };

    final formattedTotal = Formatters.formatCents(order.totalMinor);
    final formattedTime = order.createdAt != null
        ? Formatters.formatDateTime(order.createdAt!)
        : 'Unknown date';

    final semanticLabel =
        'Order ${order.reference}, $statusText, $formattedTotal USD, ${order.itemCount} items, created $formattedTime by ${order.creatorName}';

    return Semantics(
      label: semanticLabel,
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLg,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusLg,
              border: isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 2.0)
                  : null,
            ),
            child: AppCard(
              padding: AppSpacing.edgeInsetsLg,
              backgroundColor: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Header Row: Reference & Status ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            child: Text(
                              order.reference,
                              style: AppTypography.label.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusBadge(
                            label: statusText.toUpperCase(),
                            variant: statusVariant,
                            isPill: true,
                          ),
                        ],
                      );
                    },
                  ),
                  AppSpacing.gapVerticalSm,

                  // --- Metadata Row: Created at & Creator ---
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14.0,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4.0),
                      Expanded(
                        child: Text(
                          formattedTime,
                          style: AppTypography.small.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalSm,

                  // --- Footer Row: Items, Total & Action affordance ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'} · by ${order.creatorName}',
                                  style: AppTypography.small.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (order.inventoryTracked)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'Stock tracked',
                                      style: AppTypography.small.copyWith(
                                        color: cafeExt.accentCaramel,
                                        fontSize: 10.0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Total · USD',
                                        style: AppTypography.small.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 10.0,
                                        ),
                                      ),
                                      Text(
                                        formattedTotal,
                                        style: AppTypography.price.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                AppSpacing.gapHorizontalSm,
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 20.0,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
