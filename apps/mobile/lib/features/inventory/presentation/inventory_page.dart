import 'package:flutter/material.dart';

import '../../../../shared/theme/app_breakpoints.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../pos/domain/catalog_repository.dart';
import '../domain/inventory_item.dart';
import 'inventory_controller.dart';
import 'inventory_detail_page.dart';
import 'recipe_editor_page.dart';
import 'widgets/inventory_card.dart';
import 'widgets/inventory_detail_view.dart';
import 'widgets/inventory_filter_bar.dart';
import 'widgets/inventory_item_form_dialog.dart';

/// Primary production screen for inventory overview and stock management.
///
/// Supports responsive adaptation:
/// - Compact (<600dp): list with filter chips, pull-to-refresh, push navigation to detail.
/// - Expanded (≥600dp): split master-detail view with persistent list and inspector.
class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.controller,
    required this.authController,
    this.catalogRepository,
  });

  final InventoryController controller;
  final AuthController authController;
  final CatalogRepository? catalogRepository;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final ScrollController _scrollController = ScrollController();

  AuthUser? get _currentUser {
    final state = widget.authController.state;
    if (state is Authenticated) return state.user;
    return null;
  }

  bool get _canAdjustInventory =>
      _currentUser?.hasPermission('adjust-inventory') ?? false;

  bool get _canManageCatalog =>
      _currentUser?.hasPermission('manage-catalog') ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.start();
      }
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.controller.loadMore();
    }
  }

  void _openCreateItemDialog() {
    showDialog(
      context: context,
      builder: (ctx) => InventoryItemFormDialog(controller: widget.controller),
    );
  }

  void _openRecipeEditor() {
    if (widget.catalogRepository == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeEditorPage(
          controller: widget.controller,
          catalogRepository: widget.catalogRepository!,
        ),
      ),
    );
  }

  void _onItemTapped(InventoryItem item, bool isCompact) {
    widget.controller.selectItem(item);
    if (isCompact) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InventoryDetailPage(
            item: item,
            controller: widget.controller,
            canAdjustInventory: _canAdjustInventory,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = AppBreakpoints.isCompact(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          if (_canManageCatalog && widget.catalogRepository != null)
            IconButton(
              icon: const Icon(Icons.menu_book_rounded),
              tooltip: 'Product Recipes',
              onPressed: _openRecipeEditor,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Inventory',
            onPressed: () => widget.controller.refresh(),
          ),
        ],
      ),
      floatingActionButton: _canAdjustInventory
          ? FloatingActionButton.extended(
              onPressed: _openCreateItemDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Item'),
            )
          : null,
      body: SafeArea(
        child: isCompact ? _buildCompactLayout() : _buildExpandedLayout(),
      ),
    );
  }

  // =========================================================================
  // Compact (Phone <600dp) Layout
  // =========================================================================
  Widget _buildCompactLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: InventoryFilterBar(controller: widget.controller),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => widget.controller.refresh(),
            child: _buildItemList(isCompact: true),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // Expanded (Tablet/Desktop ≥600dp) Master-Detail Layout
  // =========================================================================
  Widget _buildExpandedLayout() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final selectedItem = widget.controller.selectedItem;

        return Row(
          children: [
            // Left master list pane
            SizedBox(
              width: 400,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: InventoryFilterBar(controller: widget.controller),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => widget.controller.refresh(),
                      child: _buildItemList(isCompact: false),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),

            // Right detail inspector pane
            Expanded(
              child: selectedItem == null
                  ? const Center(
                      child: AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No Item Selected',
                        description:
                            'Select an inventory item on the left to inspect balances and record movements.',
                      ),
                    )
                  : InventoryDetailView(
                      item: selectedItem,
                      controller: widget.controller,
                      canAdjustInventory: _canAdjustInventory,
                    ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // Shared Item List
  // =========================================================================
  Widget _buildItemList({required bool isCompact}) {
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoading && controller.items.isEmpty) {
          return const Center(
            child: AppLoadingIndicator(message: 'Loading inventory items...'),
          );
        }

        final failure = controller.listFailure;
        if (failure != null && controller.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: Colors.red,
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
                    onPressed: () => controller.fetchItems(),
                  ),
                ],
              ),
            ),
          );
        }

        final items = controller.items;
        if (items.isEmpty) {
          return const Center(
            child: AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No Items Found',
              description: 'Try adjusting your search or filters.',
            ),
          );
        }

        return ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length + (controller.hasMore ? 1 : 0),
          separatorBuilder: (context, index) => AppSpacing.gapVerticalSm,
          itemBuilder: (context, index) {
            if (index == items.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: controller.isLoadingMore
                      ? const AppLoadingIndicator(size: 24)
                      : AppButton(
                          label: 'Load More',
                          variant: AppButtonVariant.outline,
                          onPressed: () => controller.loadMore(),
                        ),
                ),
              );
            }

            final item = items[index];
            final isSelected =
                !isCompact && controller.selectedItem?.id == item.id;

            return InventoryCard(
              item: item,
              isSelected: isSelected,
              onTap: () => _onItemTapped(item, isCompact),
            );
          },
        );
      },
    );
  }
}
