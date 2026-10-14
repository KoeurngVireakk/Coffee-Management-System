import 'package:flutter/material.dart';

import '../../../shared/theme/app_breakpoints.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../pos/domain/order.dart';
import '../../pos/presentation/checkout_controller.dart';
import 'order_detail_page.dart';
import 'orders_controller.dart';
import 'widgets/order_card.dart';
import 'widgets/order_date_filter_bar.dart';
import 'widgets/order_detail_view.dart';
import 'widgets/order_status_filter_bar.dart';

/// Primary Order History and Status Tracking screen.
///
/// Implements responsive mobile (<600dp) and tablet (≥600dp) layouts, status
/// filtering, date-range filtering, pull-to-refresh, incremental pagination,
/// and safe order recovery navigation.
class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.controller,
    this.checkoutController,
  });

  final OrdersController controller;
  final CheckoutController? checkoutController;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.start();
      }
    });
  }

  void _openDetail(Order order, bool isCompact) {
    if (isCompact) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(
            controller: widget.controller,
            checkoutController: widget.checkoutController,
            reference: order.reference,
            initialOrder: order,
          ),
        ),
      );
    } else {
      widget.controller.selectOrder(order.reference, initialOrder: order);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isCompact = AppBreakpoints.isCompact(context);

        if (isCompact) {
          return _buildCompactLayout(context);
        } else {
          return _buildExpandedLayout(context);
        }
      },
    );
  }

  // =========================================================================
  // Compact Phone Layout (<600dp)
  // =========================================================================
  Widget _buildCompactLayout(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          AppSpacing.gapVerticalSm,
          OrderStatusFilterBar(
            selectedStatus: widget.controller.state.filter.status,
            onStatusSelected: widget.controller.setStatusFilter,
          ),
          AppSpacing.gapVerticalSm,
          OrderDateFilterBar(
            createdFrom: widget.controller.state.filter.createdFrom,
            createdTo: widget.controller.state.filter.createdTo,
            onDateRangeSelected: widget.controller.setDateFilter,
            onClearDateFilter: widget.controller.clearDateFilter,
          ),
          AppSpacing.gapVerticalSm,
          const Divider(height: 1),
          Expanded(child: _buildOrderList(context, isCompact: true)),
        ],
      ),
    );
  }

  // =========================================================================
  // Expanded Tablet Layout (≥600dp Master-Detail)
  // =========================================================================
  Widget _buildExpandedLayout(BuildContext context) {
    final detailOrder = widget.controller.detailState.order;

    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Pane: Orders List
          SizedBox(
            width: 380.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                AppSpacing.gapVerticalSm,
                OrderStatusFilterBar(
                  selectedStatus: widget.controller.state.filter.status,
                  onStatusSelected: widget.controller.setStatusFilter,
                ),
                AppSpacing.gapVerticalSm,
                OrderDateFilterBar(
                  createdFrom: widget.controller.state.filter.createdFrom,
                  createdTo: widget.controller.state.filter.createdTo,
                  onDateRangeSelected: widget.controller.setDateFilter,
                  onClearDateFilter: widget.controller.clearDateFilter,
                ),
                AppSpacing.gapVerticalSm,
                const Divider(height: 1),
                Expanded(child: _buildOrderList(context, isCompact: false)),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // Right Pane: Order Detail View
          Expanded(
            child: detailOrder != null
                ? OrderDetailView(
                    controller: widget.controller,
                    checkoutController: widget.checkoutController,
                  )
                : const Center(
                    child: AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Select an Order',
                      description:
                          'Choose an order from the list to view its complete items and payment history.',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.controller.state;
    final isFiltering = state.filter.isActive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order History',
                  style: AppTypography.h2.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Authoritative order tracking',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFiltering)
                TextButton(
                  key: const ValueKey('reset-all-filters'),
                  onPressed: state.busy
                      ? null
                      : widget.controller.clearAllFilters,
                  child: const Text('Reset All'),
                ),
              IconButton(
                key: const ValueKey('refresh-orders-button'),
                tooltip: 'Refresh orders',
                onPressed: state.busy ? null : widget.controller.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, {required bool isCompact}) {
    final theme = Theme.of(context);
    final state = widget.controller.state;
    final orders = state.orders;

    if (state.phase == OrderHistoryPhase.loading && orders.isEmpty) {
      return const Center(
        child: AppLoadingIndicator(message: 'Loading orders…'),
      );
    }

    if (state.phase == OrderHistoryPhase.error && orders.isEmpty) {
      return Center(
        child: SingleChildScrollView(
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
                state.failure?.message ?? 'Failed to load order history.',
                style: AppTypography.title.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapVerticalLg,
              FilledButton.icon(
                key: const ValueKey('retry-orders-button'),
                onPressed: widget.controller.retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.phase == OrderHistoryPhase.empty || orders.isEmpty) {
      return SingleChildScrollView(
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No orders found',
          description: state.filter.isActive
              ? 'No orders match your selected filters. Try clearing filters.'
              : 'Previously created orders will appear here.',
        ),
      );
    }

    final hasFooter =
        state.hasMore || state.phase == OrderHistoryPhase.loadingMore;
    final totalCount = orders.length + (hasFooter ? 1 : 0);
    final selectedRef = widget.controller.detailState.order?.reference;

    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: ListView.separated(
        padding: AppSpacing.edgeInsetsLg,
        itemCount: totalCount,
        separatorBuilder: (_, _) => AppSpacing.gapVerticalMd,
        itemBuilder: (context, index) {
          if (index < orders.length) {
            final order = orders[index];
            return OrderCard(
              order: order,
              isSelected: !isCompact && order.reference == selectedRef,
              onTap: () => _openDetail(order, isCompact),
            );
          }

          // Footer: Load more indicator or action
          if (state.phase == OrderHistoryPhase.loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                OutlinedButton(
                  key: const ValueKey('load-more-orders-button'),
                  onPressed: state.busy ? null : widget.controller.loadMore,
                  child: const Text('Load More Orders'),
                ),
                if (state.page != null) ...[
                  AppSpacing.gapVerticalXs,
                  Text(
                    'Showing ${orders.length} of ${state.page!.total} orders',
                    style: AppTypography.small.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
