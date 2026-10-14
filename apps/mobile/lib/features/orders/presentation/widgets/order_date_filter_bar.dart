import 'package:flutter/material.dart';

import '../../../../shared/theme/app_radius.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/theme/formatters.dart';
import '../../domain/order_filter.dart';

/// Interactive date-range filter control for order history.
///
/// Features:
/// - Explicit local timezone indication (e.g. `UTC+07:00`)
/// - Device calendar date range selection via [showDateRangePicker]
/// - Safe boundary mapping (`startOfDay` -> `endOfDay`)
/// - Clear button to reset active date filters
class OrderDateFilterBar extends StatelessWidget {
  const OrderDateFilterBar({
    super.key,
    required this.createdFrom,
    required this.createdTo,
    required this.onDateRangeSelected,
    required this.onClearDateFilter,
  });

  final DateTime? createdFrom;
  final DateTime? createdTo;
  final void Function(DateTime from, DateTime to) onDateRangeSelected;
  final VoidCallback onClearDateFilter;

  bool get hasActiveDateFilter => createdFrom != null || createdTo != null;

  String get _timeZoneLabel {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initialRange = createdFrom != null && createdTo != null
        ? DateTimeRange(start: createdFrom!, end: createdTo!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: initialRange,
      helpText: 'Filter orders by date ($_timeZoneLabel)',
      cancelText: 'Cancel',
      confirmText: 'Apply',
    );

    if (picked != null) {
      final start = OrderFilter.startOfDay(picked.start);
      final end = OrderFilter.endOfDay(picked.end);
      onDateRangeSelected(start, end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter by Date Button / Active Range Chip
          if (!hasActiveDateFilter)
            OutlinedButton.icon(
              key: const ValueKey('pick-date-filter'),
              onPressed: () => _pickDateRange(context),
              icon: const Icon(Icons.date_range_outlined, size: 18.0),
              label: Text(
                'Filter by Date ($_timeZoneLabel)',
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minTouchTarget),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            )
          else ...[
            InputChip(
              key: const ValueKey('active-date-chip'),
              avatar: const Icon(Icons.date_range_rounded, size: 18.0),
              label: Text(
                '${Formatters.formatDate(createdFrom!)} – ${Formatters.formatDate(createdTo!)} ($_timeZoneLabel)',
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: true,
              onDeleted: onClearDateFilter,
              tooltip: 'Edit date filter',
              onPressed: () => _pickDateRange(context),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusPill),
            ),
            AppSpacing.gapHorizontalSm,
            TextButton(
              key: const ValueKey('clear-date-filter'),
              onPressed: onClearDateFilter,
              child: const Text('Reset Date'),
            ),
          ],
        ],
      ),
    );
  }
}
