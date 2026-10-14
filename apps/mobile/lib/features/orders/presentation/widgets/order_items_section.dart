import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/theme/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../pos/domain/order.dart';

/// Card displaying historical purchased items and authoritative financial totals.
///
/// Historical names, prices, and quantities are immutable snapshots from the server.
class OrderItemsSection extends StatelessWidget {
  const OrderItemsSection({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: AppSpacing.edgeInsetsLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'Purchased Items',
                style: AppTypography.title.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                style: AppTypography.small.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalMd,
          const Divider(height: 1),
          AppSpacing.gapVerticalMd,

          // Line items list
          for (var i = 0; i < order.items.length; i++) ...[
            if (i > 0) const Divider(height: AppSpacing.lg),
            _buildItemRow(context, order.items[i]),
          ],

          AppSpacing.gapVerticalLg,
          const Divider(height: 1),
          AppSpacing.gapVerticalMd,

          // Financial summary
          _buildSummaryRow(
            context,
            'Subtotal',
            Formatters.formatCents(order.subtotalMinor),
          ),
          if (order.discountMinor > 0) ...[
            AppSpacing.gapVerticalXs,
            _buildSummaryRow(
              context,
              'Discount',
              '-${Formatters.formatCents(order.discountMinor)}',
            ),
          ],
          if (order.taxMinor > 0) ...[
            AppSpacing.gapVerticalXs,
            _buildSummaryRow(
              context,
              'Tax',
              Formatters.formatCents(order.taxMinor),
            ),
          ],
          AppSpacing.gapVerticalSm,
          const Divider(height: 1),
          AppSpacing.gapVerticalSm,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'Total · USD',
                style: AppTypography.title.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                Formatters.formatCents(order.totalMinor),
                style: AppTypography.priceLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, OrderItem item) {
    final theme = Theme.of(context);
    final unitPrice = Formatters.formatCents(item.unitPriceMinor);
    final lineTotal = Formatters.formatCents(item.lineTotalMinor);

    return Semantics(
      label:
          '${item.productName}, ${item.quantity} at $unitPrice each, line total $lineTotal USD',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Text(
              '${item.quantity}×',
              style: AppTypography.label.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AppSpacing.gapHorizontalMd,

          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'SKU: ${item.productSku} · $unitPrice each',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Line total
          Text(
            lineTotal,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
