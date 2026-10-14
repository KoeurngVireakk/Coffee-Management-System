import 'package:flutter/material.dart';

import '../../../../shared/theme/app_radius.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/theme/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../pos/domain/order.dart';
import '../../../pos/domain/payment.dart';

/// Card displaying accepted settlement details and all payment attempts for an order.
class OrderPaymentSection extends StatelessWidget {
  const OrderPaymentSection({
    super.key,
    required this.order,
    required this.payments,
    this.hasMorePayments = false,
    this.isLoadingMore = false,
    this.onLoadMorePayments,
  });

  final Order order;
  final List<Payment> payments;
  final bool hasMorePayments;
  final bool isLoadingMore;
  final VoidCallback? onLoadMorePayments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accepted = order.acceptedPayment;

    return AppCard(
      padding: AppSpacing.edgeInsetsLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Payment & Settlement',
            style: AppTypography.title.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.gapVerticalMd,
          const Divider(height: 1),
          AppSpacing.gapVerticalMd,

          // --- Settled Payment Information (if paid) ---
          if (order.status == OrderStatus.paid && accepted != null) ...[
            _buildSettlementCard(context, accepted),
            AppSpacing.gapVerticalLg,
          ],

          // --- Reconciliation warning (if any attempt requires review) ---
          if (payments.any((p) => p.reconciliationRequired)) ...[
            _buildReviewWarning(context),
            AppSpacing.gapVerticalLg,
          ],

          // --- Payment Attempts Header ---
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'Payment Attempts',
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${payments.length} recorded',
                style: AppTypography.small.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalSm,

          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'No payment attempts recorded for this order.',
                style: AppTypography.small.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            for (var i = 0; i < payments.length; i++) ...[
              if (i > 0) const Divider(height: AppSpacing.md),
              _buildAttemptRow(context, payments[i]),
            ],
          ],

          if (hasMorePayments) ...[
            AppSpacing.gapVerticalMd,
            OutlinedButton(
              onPressed: isLoadingMore ? null : onLoadMorePayments,
              child: Text(
                isLoadingMore
                    ? 'Loading more attempts…'
                    : 'Load More Payment Attempts',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettlementCard(BuildContext context, Payment payment) {
    final theme = Theme.of(context);
    final isCash = payment.method == PaymentMethod.cash;

    return Container(
      padding: AppSpacing.edgeInsetsMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isCash ? Icons.payments_rounded : Icons.qr_code_2_rounded,
                    color: theme.colorScheme.primary,
                    size: 20.0,
                  ),
                  AppSpacing.gapHorizontalSm,
                  Text(
                    isCash
                        ? 'Settled with Cash'
                        : 'Settled with External Payment',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const StatusBadge(
                label: 'SETTLED',
                variant: StatusBadgeVariant.success,
                isPill: true,
              ),
            ],
          ),
          if (isCash && payment.tenderMinor != null) ...[
            AppSpacing.gapVerticalSm,
            Text(
              'Cash Received: ${Formatters.formatCents(payment.tenderMinor!)} USD',
              style: AppTypography.small.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (payment.changeMinor != null)
              Text(
                'Change Returned: ${Formatters.formatCents(payment.changeMinor!)} USD',
                style: AppTypography.small.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          if (order.paidAt != null) ...[
            AppSpacing.gapVerticalXs,
            Text(
              'Paid At: ${Formatters.formatDateTime(order.paidAt!)}',
              style: AppTypography.small.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewWarning(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: AppSpacing.edgeInsetsMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 24.0,
          ),
          AppSpacing.gapHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reconciliation Required',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                AppSpacing.gapVerticalXs,
                Text(
                  'One or more payment attempts require review. Do not collect another payment or assume this payment succeeded until verified by your manager.',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptRow(BuildContext context, Payment payment) {
    final theme = Theme.of(context);
    final statusVariant = switch (payment.status) {
      PaymentStatus.confirmed => StatusBadgeVariant.success,
      PaymentStatus.pending => StatusBadgeVariant.warning,
      PaymentStatus.initiated => StatusBadgeVariant.information,
      PaymentStatus.uncertain => StatusBadgeVariant.warning,
      PaymentStatus.failed => StatusBadgeVariant.error,
      PaymentStatus.expired => StatusBadgeVariant.neutral,
    };

    final statusText = switch (payment.status) {
      PaymentStatus.confirmed => 'Confirmed',
      PaymentStatus.pending => 'Pending',
      PaymentStatus.initiated => 'Initiated',
      PaymentStatus.uncertain => 'Uncertain',
      PaymentStatus.failed => 'Failed',
      PaymentStatus.expired => 'Expired',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#${payment.id} · ${payment.method == PaymentMethod.cash ? 'Cash' : 'External'}',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (payment.reconciliationRequired) ...[
                    AppSpacing.gapHorizontalXs,
                    const StatusBadge(
                      label: 'REVIEW',
                      variant: StatusBadgeVariant.error,
                      isPill: true,
                    ),
                  ],
                ],
              ),
              if (payment.provider != null)
                Text(
                  'Provider: ${payment.provider}',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (payment.createdAt != null)
                Text(
                  Formatters.formatDateTime(payment.createdAt!),
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatusBadge(
              label: statusText.toUpperCase(),
              variant: statusVariant,
              isPill: true,
            ),
            AppSpacing.gapVerticalXs,
            Text(
              Formatters.formatCents(payment.expectedAmountMinor),
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
