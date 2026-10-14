import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../inventory_controller.dart';

/// Search input and filter chips for inventory items.
class InventoryFilterBar extends StatefulWidget {
  const InventoryFilterBar({super.key, required this.controller});

  final InventoryController controller;

  @override
  State<InventoryFilterBar> createState() => _InventoryFilterBarState();
}

class _InventoryFilterBarState extends State<InventoryFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.filter.search ?? '',
    );
  }

  @override
  void didUpdateWidget(InventoryFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentSearch = widget.controller.filter.search ?? '';
    if (_searchController.text != currentSearch &&
        !_searchController.value.isComposingRangeValid) {
      _searchController.text = currentSearch;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = widget.controller.filter;

    // Filter chip presets
    final isAll = filter.status == 'all' && filter.lowStock == null;
    final isLowStock = filter.lowStock == true;
    final isActive = filter.status == 'active' && filter.lowStock == null;
    final isInactive = filter.status == 'inactive' && filter.lowStock == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Search Field ---
        TextField(
          controller: _searchController,
          onChanged: (val) => widget.controller.setSearch(val),
          decoration: InputDecoration(
            hintText: 'Search inventory by name or SKU...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      widget.controller.clearSearch();
                    },
                  )
                : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          style: AppTypography.body,
        ),
        AppSpacing.gapVerticalSm,

        // --- Filter Chips Bar ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: isAll,
                onSelected: (selected) {
                  if (selected) {
                    widget.controller.setLowStock(null);
                    widget.controller.setStatus('all');
                  }
                },
              ),
              AppSpacing.gapHorizontalSm,
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16),
                    SizedBox(width: 4),
                    Text('Low Stock'),
                  ],
                ),
                selected: isLowStock,
                onSelected: (selected) {
                  if (selected) {
                    widget.controller.setStatus('all');
                    widget.controller.setLowStock(true);
                  } else {
                    widget.controller.setLowStock(null);
                  }
                },
              ),
              AppSpacing.gapHorizontalSm,
              ChoiceChip(
                label: const Text('Active'),
                selected: isActive,
                onSelected: (selected) {
                  if (selected) {
                    widget.controller.setLowStock(null);
                    widget.controller.setStatus('active');
                  }
                },
              ),
              AppSpacing.gapHorizontalSm,
              ChoiceChip(
                label: const Text('Inactive'),
                selected: isInactive,
                onSelected: (selected) {
                  if (selected) {
                    widget.controller.setLowStock(null);
                    widget.controller.setStatus('inactive');
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
