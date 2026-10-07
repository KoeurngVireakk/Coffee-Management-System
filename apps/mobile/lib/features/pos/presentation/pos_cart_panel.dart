import 'package:flutter/material.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/formatters.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../domain/cart.dart';
import 'pos_controller.dart';

void showCartLimit(BuildContext context, CartLimit? limit) {
  if (limit == null) return;
  final message = switch (limit) {
    CartLimit.quantity =>
      'A product can have at most 99 items. Remove items to add more.',
    CartLimit.lines =>
      'An order can have at most 50 different products. Remove a product to add another.',
    CartLimit.unavailable =>
      'This product is unavailable. Refresh the catalog.',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class PosCartPanel extends StatelessWidget {
  const PosCartPanel({super.key, required this.controller, this.onClose});
  final PosController controller;
  final VoidCallback? onClose;

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this order?'),
        content: const Text(
          'All products will be removed from the current order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear order'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) controller.clearCart();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final cart = controller.cart;
        final colors = Theme.of(context).colorScheme;
        return Material(
          color: colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AppSpacing.edgeInsetsLg,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(
                      'Current Order',
                      style: AppTypography.h3.copyWith(color: colors.onSurface),
                    ),
                    if (cart.distinctCount > 0)
                      TextButton(
                        onPressed: () => _clear(context),
                        child: const Text('Clear cart'),
                      ),
                    if (onClose != null)
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppSpacing.minTouchTarget,
                          minHeight: AppSpacing.minTouchTarget,
                        ),
                        tooltip: 'Close cart',
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: cart.distinctCount == 0
                    ? SingleChildScrollView(
                        child: AppEmptyState(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Your order is empty',
                          description: 'Choose a product to start your order.',
                        ),
                      )
                    : ListView.separated(
                        padding: AppSpacing.edgeInsetsLg,
                        itemCount: cart.distinctCount,
                        separatorBuilder: (_, _) => const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Divider(),
                        ),
                        itemBuilder: (context, index) => _CartLineView(
                          line: cart.lines[index],
                          controller: controller,
                        ),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: AppSpacing.edgeInsetsLg,
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${cart.itemCount} items · ${cart.distinctCount} products',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      AppSpacing.gapVerticalSm,
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: AppSpacing.md,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Subtotal · USD'),
                          Text(
                            Formatters.formatCents(cart.subtotalMinor),
                            style: AppTypography.price.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapVerticalSm,
                      Text(
                        'Price preview. Checkout is coming next.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CartLineView extends StatelessWidget {
  const _CartLineView({required this.line, required this.controller});
  final CartLine line;
  final PosController controller;

  @override
  Widget build(BuildContext context) {
    final product = line.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapVerticalXs,
        Text(
          '${Formatters.formatCents(product.priceMinor)} each · ${Formatters.formatCents(line.subtotalMinor)} line subtotal',
        ),
        AppSpacing.gapVerticalSm,
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              constraints: const BoxConstraints(
                minWidth: AppSpacing.minTouchTarget,
                minHeight: AppSpacing.minTouchTarget,
              ),
              tooltip: 'Decrease ${product.name} quantity',
              onPressed: line.quantity > 1
                  ? () => controller.decrement(product.id)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Semantics(
              label: '${product.name} quantity ${line.quantity}',
              child: ExcludeSemantics(
                child: Text(
                  '${line.quantity}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              constraints: const BoxConstraints(
                minWidth: AppSpacing.minTouchTarget,
                minHeight: AppSpacing.minTouchTarget,
              ),
              tooltip: 'Increase ${product.name} quantity',
              onPressed: () =>
                  showCartLimit(context, controller.increment(product.id)),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              constraints: const BoxConstraints(
                minWidth: AppSpacing.minTouchTarget,
                minHeight: AppSpacing.minTouchTarget,
              ),
              tooltip: 'Remove ${product.name}',
              onPressed: () => controller.remove(product.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        if (line.quantity == Cart.maxQuantity)
          const Text('99-item limit reached'),
      ],
    );
  }
}
