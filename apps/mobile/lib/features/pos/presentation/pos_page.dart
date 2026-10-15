import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/app_breakpoints.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../domain/catalog_repository.dart';
import 'pos_cart_panel.dart';
import 'pos_cart_summary.dart';
import 'pos_controller.dart';
import 'pos_product_card.dart';

/// Presentation only: one session-owned controller across every layout branch.
class PosPage extends StatefulWidget {
  const PosPage({super.key, required this.controller});
  final PosController controller;
  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  late final TextEditingController _search;
  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.controller.search);
    widget.controller.start();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: math.min(
              MediaQuery.sizeOf(context).height * .85,
              constraints.maxHeight,
            ),
            child: PosCartPanel(
              controller: widget.controller,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          // 1024px tablet minus the existing 280px sidebar leaves 744px.
          // Never force narrow/high-type allocations into a cramped split.
          final split =
              constraints.maxWidth >= 720 * math.max(1, scale) &&
              constraints.maxHeight >= 480;
          const cartWidth = 304.0;
          final catalog = _catalog(
            context,
            constraints.maxWidth - (split ? cartWidth + 1 : 0),
          );
          if (split) {
            return Row(
              children: [
                Expanded(child: catalog),
                const VerticalDivider(width: 1),
                const SizedBox(width: AppSpacing.s),
                SizedBox(
                  width: cartWidth - AppSpacing.s,
                  child: PosCartPanel(controller: widget.controller),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: catalog),
              PosCartSummary(
                controller: widget.controller,
                onPressed: _openCart,
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _catalog(BuildContext context, double width) {
    final controller = widget.controller;
    final products = controller.products;
    final categories = controller.categories;
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final columns = math.max(
      1,
      ((width - AppSpacing.xxxl + AppSpacing.md) / (160 * math.max(1, scale)))
          .floor(),
    );
    final sameFailure =
        categories.failure != null &&
        products.failure != null &&
        categories.failure!.kind == products.failure!.kind;
    Future<void> retryProducts() => products.hasMore
        ? controller.loadMoreProducts()
        : controller.retryProducts();
    Future<void> retryCategories() => categories.hasMore
        ? controller.loadMoreCategories()
        : controller.retryCategories();

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        key: const PageStorageKey('pos-catalog'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Point of Sale',
                          style: AppTypography.title.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: 'Refresh catalog',
                        onPressed: products.busy || categories.busy
                            ? null
                            : controller.refresh,
                        icon: const Icon(Icons.refresh, size: 22),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalSm,
                  Semantics(
                    label: 'Search products by name or SKU',
                    child: TextField(
                      controller: _search,
                      onChanged: controller.setSearch,
                      style: AppTypography.body.copyWith(
                        color: colors.onSurface,
                      ),
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (old, next) =>
                              next.text.runes.length <= 80 ? next : old,
                        ),
                      ],
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hint: const ExcludeSemantics(
                          child: Text('Search menu'),
                        ),
                        prefixIcon: const ExcludeSemantics(
                          child: Icon(Icons.search, size: 22),
                        ),
                        suffixIcon: IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            controller.setSearch('');
                          },
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapVerticalSm,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _categoryChip(context, 'All', null),
                        if (controller.selectedCategory != null &&
                            !categories.items.any(
                              (category) =>
                                  category.id == controller.categoryId,
                            ))
                          _categoryChip(
                            context,
                            controller.selectedCategory!.name,
                            controller.categoryId,
                          ),
                        for (final category in categories.items)
                          _categoryChip(context, category.name, category.id),
                        if (categories.hasMore)
                          TextButton(
                            onPressed: categories.busy
                                ? null
                                : controller.loadMoreCategories,
                            child: Text(
                              categories.busy
                                  ? 'Loading categories…'
                                  : 'More categories',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (categories.phase == CatalogPhase.loading)
                    const Text('Loading categories…'),
                  if (categories.phase == CatalogPhase.empty)
                    Text(
                      'No active categories',
                      style: AppTypography.small.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  if (sameFailure)
                    _failure(context, products.failure!, () async {
                      await Future.wait([retryCategories(), retryProducts()]);
                    }, scope: 'Catalog')
                  else ...[
                    if (categories.failure != null)
                      _failure(
                        context,
                        categories.failure!,
                        retryCategories,
                        scope: 'Categories',
                      ),
                    if (products.failure != null)
                      _failure(
                        context,
                        products.failure!,
                        retryProducts,
                        scope: 'Products',
                      ),
                  ],
                  if (products.failure != null && products.items.isNotEmpty)
                    const Text('Showing previously loaded products.'),
                  if (products.busy && products.items.isNotEmpty)
                    AppMotion.respectingPreferences(
                              context,
                              AppMotion.hoverFocus,
                            ) ==
                            Duration.zero
                        ? const Text('Updating products')
                        : const LinearProgressIndicator(
                            semanticsLabel: 'Updating products',
                          ),
                ],
              ),
            ),
          ),
          if (products.items.isEmpty && products.busy)
            SliverToBoxAdapter(child: _loading(context, columns)),
          if (products.phase == CatalogPhase.empty)
            SliverToBoxAdapter(
              child: AppEmptyState(
                icon: Icons.restaurant_menu_outlined,
                title: controller.search.isNotEmpty
                    ? 'No search results'
                    : controller.categoryId != null
                    ? 'No products in this category'
                    : 'No products available',
                description:
                    controller.search.isNotEmpty ||
                        controller.categoryId != null
                    ? 'Try another search or choose All.'
                    : 'Ask your manager to add products to the catalog.',
              ),
            ),
          SliverPadding(
            padding: AppSpacing.edgeInsetsLg,
            sliver: SliverList.builder(
              itemCount: (products.items.length / columns).ceil(),
              itemBuilder: (context, row) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) AppSpacing.gapHorizontalMd,
                        Expanded(
                          child: row * columns + column >= products.items.length
                              ? const SizedBox.shrink()
                              : PosProductCard(
                                  product:
                                      products.items[row * columns + column],
                                  quantity: controller.cart.quantityFor(
                                    products.items[row * columns + column].id,
                                  ),
                                  onAdd: !controller.canEditCart
                                      ? null
                                      : () => showCartLimit(
                                          context,
                                          controller.add(
                                            products.items[row * columns +
                                                column],
                                          ),
                                        ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (products.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.edgeInsetsLg,
                child: OutlinedButton(
                  onPressed: products.busy ? null : controller.loadMoreProducts,
                  child: Text(
                    products.phase == CatalogPhase.loadingMore
                        ? 'Loading more…'
                        : 'Load more products',
                  ),
                ),
              ),
            ),
          if (products.page != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.edgeInsetsLg,
                child: Text(
                  '${products.items.length} of ${products.page!.total} products',
                  style: AppTypography.small.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(BuildContext context, String name, int? id) {
    final colors = Theme.of(context).colorScheme;
    final selected = widget.controller.categoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(name),
        labelStyle: AppTypography.label.copyWith(
          color: selected ? colors.onPrimary : colors.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        selected: selected,
        showCheckmark: true,
        checkmarkColor: colors.onPrimary,
        selectedColor: colors.primary,
        backgroundColor: colors.surface,
        side: BorderSide(
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: (_) => widget.controller.selectCategory(id),
      ),
    );
  }

  Widget _failure(
    BuildContext context,
    CatalogFailure failure,
    VoidCallback retry, {
    required String scope,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: AppSpacing.edgeInsetsMd,
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: AppRadius.radiusLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$scope unavailable',
                style: AppTypography.label.copyWith(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppSpacing.gapVerticalXs,
              Text(
                failure.message,
                style: AppTypography.body.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
              TextButton(onPressed: retry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading(BuildContext context, int columns) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: AppSpacing.edgeInsetsLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(liveRegion: true, child: const Text('Loading catalog…')),
          AppSpacing.gapVerticalMd,
          ExcludeSemantics(
            child: Column(
              children: [
                for (var row = 0; row < 2; row++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        for (var i = 0; i < columns; i++) ...[
                          if (i > 0) AppSpacing.gapHorizontalMd,
                          Expanded(
                            child: Container(
                              height: 148,
                              padding: AppSpacing.edgeInsetsMd,
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: AppRadius.radiusXl,
                                border: Border.all(
                                  color: colors.outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 12,
                                    color: colors.outlineVariant,
                                  ),
                                  AppSpacing.gapVerticalLg,
                                  Container(
                                    height: 18,
                                    color: colors.outlineVariant,
                                  ),
                                  const Spacer(),
                                  Container(
                                    width: 56,
                                    height: 22,
                                    color: colors.outlineVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
