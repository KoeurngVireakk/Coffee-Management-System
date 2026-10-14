import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../../pos/domain/order.dart';

/// Horizontal status filter bar with accessible ChoiceChips.
class OrderStatusFilterBar extends StatelessWidget {
  const OrderStatusFilterBar({
    super.key,
    required this.selectedStatus,
    required this.onStatusSelected,
  });

  final OrderStatus? selectedStatus;
  final ValueChanged<OrderStatus?> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    const filters = [
      (label: 'All', status: null),
      (label: 'Pending', status: OrderStatus.pendingPayment),
      (label: 'Paid', status: OrderStatus.paid),
      (label: 'Cancelled', status: OrderStatus.cancelled),
      (label: 'Expired', status: OrderStatus.expired),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: filters.map((f) {
          final isSelected = selectedStatus == f.status;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              key: ValueKey('filter-status-${f.label.toLowerCase()}'),
              label: Text(f.label),
              selected: isSelected,
              showCheckmark: true,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onStatusSelected(f.status),
            ),
          );
        }).toList(),
      ),
    );
  }
}
