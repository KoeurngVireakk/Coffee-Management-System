import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_breakpoints.dart';
import '../../../../shared/theme/app_radius.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/theme/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../pos/domain/order.dart';
import '../../../pos/presentation/checkout_controller.dart';
import '../../../pos/presentation/checkout_panel.dart';
import '../orders_controller.dart';
import 'order_items_section.dart';
import 'order_payment_section.dart';
import 'order_recovery_section.dart';

/// Content view for displaying order details, shared between full-page mobile
/// navigation and tablet split-screen master-detail layouts.
class OrderDetailView extends StatefulWidget {
  const OrderDetailView({
    super.key,
    required this.controller,
    this.checkoutController,
  });

  final OrdersController controller;
  final CheckoutController? checkoutController;

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  bool _isRecovering = false;

  Future<void> _handleResumePayment(Order order) async {
    final checkout = widget.checkoutController;
    if (checkout == null) return;

    setState(() => _isRecovering = true);
    try {
      await checkout.recoverOrder(order.reference);
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: math.min(
                MediaQuery.sizeOf(context).height * 0.9,
                constraints.maxHeight,
              ),
              child: CheckoutPanel(
                controller: checkout,
                onClose: () => Navigator.pop(sheetContext),
              ),
            ),
          ),
        ),
      );

      if (mounted) {
        await widget.controller.refreshOrderDetail();
      }
    } finally {
      if (mounted) {
        setState(() => _isRecovering = false);
      }
    }
  }

  Future<void> _handleCancelOrder(Order order) async {
    final checkout = widget.checkoutController;
    if (checkout == null) return;

    setState(() => _isRecovering = true);
    try {
      await checkout.recoverOrder(order.reference);
      await checkout.cancel();
      if (mounted) {
        await widget.controller.refreshOrderDetail();
      }
    } finally {
      if (mounted) {
        setState(() => _isRecovering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final detailState = widget.controller.detailState;
        final order = detailState.order;

        if (detailState.phase == OrderDetailPhase.loading && order == null) {
          return const Center(
            child: AppLoadingIndicator(
              message: 'Loading authoritative order details…',
            ),
          );
        }

        if (detailState.phase == OrderDetailPhase.error && order == null) {
          return Center(
            child: Padding(
              padding: AppSpacing.edgeInsetsXxl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48.0,
                    color: theme.colorScheme.error,
                  ),
                  AppSpacing.gapVerticalMd,
                  Text(
                    detailState.failure?.message ??
                        'Failed to load order details.',
                    style: AppTypography.title.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapVerticalLg,
                  FilledButton.icon(
                    onPressed: () => widget.controller.refreshOrderDetail(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (order == null) {
          return const SizedBox.shrink();
        }

        return RefreshIndicator(
          onRefresh: widget.controller.refreshOrderDetail,
          child: ListView(
            padding: AppSpacing.edgeInsetsLg,
            children: [
              if (detailState.busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Refreshing order state',
                  ),
                ),

              if (detailState.failure != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: AppSpacing.edgeInsetsMd,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Text(
                    detailState.failure!.message,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),

              // --- Order Metadata Header Card ---
              _buildHeaderCard(context, order),
              AppSpacing.gapVerticalLg,

              // --- Purchased Items Section ---
              OrderItemsSection(order: order),
              AppSpacing.gapVerticalLg,

              // --- Payment & Settlement Section ---
              OrderPaymentSection(
                order: order,
                payments: detailState.payments,
                hasMorePayments: detailState.hasMorePayments,
                isLoadingMore:
                    detailState.phase == OrderDetailPhase.loadingMorePayments,
                onLoadMorePayments: widget.controller.loadMoreDetailPayments,
              ),
              AppSpacing.gapVerticalLg,

              // --- Safe Recovery Section (for pending orders) ---
              if (order.status == OrderStatus.pendingPayment)
                OrderRecoverySection(
                  order: order,
                  canResumePayment:
                      widget.controller.canResumePayment &&
                      widget.checkoutController != null,
                  requiresReview: widget.controller.detailRequiresReview,
                  hasBlockingPayments:
                      widget.controller.detailHasBlockingPayments,
                  hasMorePayments: detailState.hasMorePayments,
                  isActionInProgress: _isRecovering,
                  onResumePayment: () => _handleResumePayment(order),
                  onCancelOrder: () => _handleCancelOrder(order),
                  onRefreshStatus: widget.controller.refreshOrderDetail,
                ),

              AppSpacing.gapVerticalXxl,
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context, Order order) {
    final theme = Theme.of(context);

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

    return AppCard(
      padding: AppSpacing.edgeInsetsLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Public Reference',
                    style: AppTypography.small.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.gapVerticalXs,
                  Semantics(
                    label: 'Order reference ${order.reference}',
                    child: SelectableText(
                      order.reference,
                      style: AppTypography.title.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              StatusBadge(
                label: statusText.toUpperCase(),
                variant: statusVariant,
                isPill: true,
              ),
            ],
          ),
          AppSpacing.gapVerticalMd,
          const Divider(height: 1),
          AppSpacing.gapVerticalMd,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Created At',
                    style: AppTypography.small.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    order.createdAt != null
                        ? Formatters.formatDateTime(order.createdAt!)
                        : 'Unknown date',
                    style: AppTypography.small.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Created By',
                    style: AppTypography.small.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${order.creatorName} (#${order.creatorId})',
                    style: AppTypography.small.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (order.inventoryTracked) ...[
            AppSpacing.gapVerticalSm,
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14.0,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Inventory tracked by order',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
