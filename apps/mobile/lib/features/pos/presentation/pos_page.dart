import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/theme/app_breakpoints.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/formatters.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import 'pos_cart_panel.dart';
import 'pos_controller.dart';
import 'pos_product_card.dart';

/// Only layout and interaction wiring live here; state survives widget branches.
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
              MediaQuery.sizeOf(context).height * 0.85,
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
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            // The shell's sidebar already consumes width. Also allow room for text.
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final split =
                constraints.maxWidth >=
                AppBreakpoints.expanded * math.max(1, textScale);
            final catalog = _catalog(
              context,
              constraints.maxWidth - (split ? 360 : 0),
            );
            if (split) {
              return Row(
                children: [
                  Expanded(child: catalog),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 360,
                    child: PosCartPanel(controller: widget.controller),
                  ),
                ],
              );
            }
            final cart = widget.controller.cart;
            final order = widget.controller.checkout?.state.order;
            return Column(
              children: [
                Expanded(child: catalog),
                Padding(
                  padding: AppSpacing.edgeInsetsLg,
                  child: Semantics(
                    liveRegion: true,
                    child: FilledButton(
                      key: const ValueKey('open-cart'),
                      onPressed: _openCart,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSecondary,
                        minimumSize: const Size(
                          double.infinity,
                          AppSpacing.minTouchTarget,
                        ),
                        padding: AppSpacing.edgeInsetsLg,
                      ),
                      child: Wrap(
                        spacing: AppSpacing.md,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.shopping_bag_outlined),
                          Text(
                            order == null
                                ? 'View cart · ${cart.itemCount} items'
                                : 'View order · ${order.itemCount} items',
                          ),
                          Text(
                            '${Formatters.formatCents(order?.totalMinor ?? cart.subtotalMinor)} USD',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _catalog(BuildContext context, double width) {
    final controller = widget.controller;
    final products = controller.products;
    final categories = controller.categories;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final minimumCardWidth = width < AppBreakpoints.compact ? 160 : 224;
    final columns = math.max(
      1,
      ((width - AppSpacing.xxxl + AppSpacing.md) /
              (minimumCardWidth * math.max(1, textScale)))
          .floor(),
    );
    return CustomScrollView(
      key: const PageStorageKey('pos-catalog'),
      slivers: [
        SliverPadding(
          padding: AppSpacing.edgeInsetsLg,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Point of Sale',
                      style: AppTypography.h2.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      tooltip: 'Refresh catalog',
                      onPressed: products.busy || categories.busy
                          ? null
                          : controller.refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                Text(
                  'Build your next order',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                AppSpacing.gapVerticalLg,
                TextField(
                  controller: _search,
                  onChanged: controller.setSearch,
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) => newValue.text.runes.length <= 80
                          ? newValue
                          : oldValue,
                    ),
                  ],
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search products by name or SKU',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        controller.setSearch('');
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                AppSpacing.gapVerticalLg,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _categoryChip(context, 'All', null),
                      if (controller.selectedCategory != null &&
                          !categories.items.any(
                            (category) => category.id == controller.categoryId,
                          ))
                        _categoryChip(
                          context,
                          controller.selectedCategory!.name,
                          controller.categoryId,
                        ),
                      for (final category in categories.items)
                        _categoryChip(context, category.name, category.id),
                      if (categories.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: TextButton(
                            onPressed: categories.busy
                                ? null
                                : controller.loadMoreCategories,
                            child: Text(
                              categories.busy
                                  ? 'Loading categories…'
                                  : 'More categories',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (categories.phase == CatalogPhase.loading)
                  const Padding(
                    padding: AppSpacing.edgeInsetsSm,
                    child: Text('Loading categories…'),
                  ),
                if (categories.phase == CatalogPhase.empty)
                  const Text('No active categories'),
                if (categories.failure != null)
                  _failure(
                    context,
                    categories.failure!.message,
                    controller.retryCategories,
                  ),
                AppSpacing.gapVerticalLg,
                if (products.busy && products.items.isNotEmpty)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Updating products',
                  ),
                if (products.failure != null)
                  _failure(
                    context,
                    products.failure!.message,
                    products.hasMore
                        ? controller.loadMoreProducts
                        : controller.retryProducts,
                  ),
                if (products.failure != null && products.items.isNotEmpty)
                  const Text('Showing previously loaded products.'),
              ],
            ),
          ),
        ),
        if (products.items.isEmpty && products.busy)
          const SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.edgeInsetsXxl,
              child: AppLoadingIndicator(message: 'Loading catalog…'),
            ),
          ),
        if (products.phase == CatalogPhase.empty)
          SliverToBoxAdapter(
            child: AppEmptyState(
              icon: Icons.search_off,
              title: controller.search.isNotEmpty
                  ? 'No search results'
                  : controller.categoryId != null
                  ? 'No products in this category'
                  : 'No products available',
              description:
                  controller.search.isNotEmpty || controller.categoryId != null
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
                                product: products.items[row * columns + column],
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
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }

  Widget _categoryChip(BuildContext context, String name, int? id) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.sm),
    child: ChoiceChip(
      label: Text(name),
      selected: widget.controller.categoryId == id,
      showCheckmark: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: (_) => widget.controller.selectCategory(id),
    ),
  );

  Widget _failure(BuildContext context, String message, VoidCallback retry) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Semantics(
          liveRegion: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Padding(
              padding: AppSpacing.edgeInsetsMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  TextButton(onPressed: retry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
}
