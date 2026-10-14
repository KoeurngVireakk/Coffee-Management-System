import 'package:flutter/material.dart';

import '../../../../shared/theme/app_radius.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../pos/domain/order.dart';

/// Card providing safe, authoritative actions for pending orders.
class OrderRecoverySection extends StatelessWidget {
  const OrderRecoverySection({
    super.key,
    required this.order,
    required this.canResumePayment,
    required this.requiresReview,
    required this.hasBlockingPayments,
    required this.hasMorePayments,
    required this.onResumePayment,
    required this.onCancelOrder,
    required this.onRefreshStatus,
    this.isActionInProgress = false,
  });

  final Order order;
  final bool canResumePayment;
  final bool requiresReview;
  final bool hasBlockingPayments;
  final bool hasMorePayments;
  final VoidCallback onResumePayment;
  final VoidCallback onCancelOrder;
  final VoidCallback onRefreshStatus;
  final bool isActionInProgress;

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this pending order?'),
        content: const Text(
          'The server will cancel the unpaid order and release any reserved stock. This does not refund a payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onCancelOrder();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (order.status != OrderStatus.pendingPayment) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return AppCard(
      padding: AppSpacing.edgeInsetsLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending_actions_rounded,
                color: theme.colorScheme.primary,
                size: 24.0,
              ),
              AppSpacing.gapHorizontalSm,
              Expanded(
                child: Text(
                  'Pending Order Actions',
                  style: AppTypography.title.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'This order has not been settled. You can authoritatively refresh its payment state, safely resume settlement, or cancel the unpaid order.',
            style: AppTypography.small.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapVerticalLg,

          // Status guidance alerts
          if (requiresReview)
            Container(
              padding: AppSpacing.edgeInsetsMd,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Text(
                'A payment attempt requires review. Direct payment actions are disabled until manager verification.',
                style: AppTypography.small.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (hasBlockingPayments)
            Container(
              padding: AppSpacing.edgeInsetsMd,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Text(
                'An in-flight or uncertain payment attempt exists. Inspect or reconcile its status before taking another payment.',
                style: AppTypography.small.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (hasMorePayments)
            Container(
              padding: AppSpacing.edgeInsetsMd,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.radiusMd,
              ),
              child: Text(
                'Please load all payment attempt pages before initiating another payment.',
                style: AppTypography.small.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // Primary action: Resume Payment
          AppButton(
            label: 'Resume Payment Workflow',
            leadingIcon: Icons.payment_rounded,
            isFullWidth: true,
            isLoading: isActionInProgress,
            onPressed: canResumePayment ? onResumePayment : null,
          ),
          AppSpacing.gapVerticalSm,

          // Secondary action: Refresh Status
          AppButton(
            label: 'Refresh Status',
            variant: AppButtonVariant.outline,
            leadingIcon: Icons.refresh_rounded,
            isFullWidth: true,
            onPressed: isActionInProgress ? null : onRefreshStatus,
          ),
          AppSpacing.gapVerticalSm,

          // Destructive action: Cancel order
          TextButton.icon(
            onPressed: canResumePayment && !isActionInProgress
                ? () => _confirmCancel(context)
                : null,
            icon: Icon(
              Icons.cancel_outlined,
              size: 18.0,
              color: canResumePayment ? theme.colorScheme.error : null,
            ),
            label: Text(
              'Cancel Unpaid Order',
              style: TextStyle(
                color: canResumePayment ? theme.colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
