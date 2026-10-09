import 'package:flutter/material.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/formatters.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../domain/cart.dart';
import 'pos_controller.dart';
import 'checkout_controller.dart';
import 'checkout_panel.dart';

void showCartLimit(BuildContext context, CartLimit? limit) {
  if (limit == null) return;
  final message = switch (limit) {
    CartLimit.quantity =>
      'A product can have at most 99 items. Remove items to add more.',
    CartLimit.lines =>
      'An order can have at most 50 different products. Remove a product to add another.',
    CartLimit.unavailable =>
      'This product is unavailable. Refresh the catalog.',
    CartLimit.checkoutLocked =>
      'Finish or resolve the current order before changing the cart.',
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
        final checkout = controller.checkout;
        if (checkout != null && checkout.state.phase != CheckoutPhase.draft) {
          return CheckoutPanel(controller: checkout, onClose: onClose);
        }
        final cart = controller.cart;
        final colors = Theme.of(context).colorScheme;
        final header = Padding(
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
                  tooltip: 'Close cart',
                  onPressed: onClose,
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTarget,
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        );
        final summary = Padding(
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
                  checkout == null
                      ? 'Price preview. Checkout is coming next.'
                      : 'Preview only. The server verifies prices and availability.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (checkout?.state.failure != null)
                  Padding(
                    padding: AppSpacing.edgeInsetsSm,
                    child: Text(
                      checkout!.state.failure!.message,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                if (checkout != null) ...[
                  AppSpacing.gapVerticalSm,
                  FilledButton(
                    onPressed: checkout.canCheckout ? checkout.checkout : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                        double.infinity,
                        AppSpacing.minTouchTarget,
                      ),
                    ),
                    child: const Text('Checkout'),
                  ),
                ],
              ],
            ),
          ),
        );
        const empty = AppEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your order is empty',
          description: 'Choose a product to start your order.',
        );
        final lines = cart.lines;
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(visualDensity: VisualDensity.standard),
          child: Material(
            color: colors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep fixed totals where they fit; short/high-text allocations scroll
                // the whole review so neither Checkout nor item controls are clipped.
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final needsScroll =
                    checkout != null &&
                    constraints.maxHeight <
                        AppSpacing.minTouchTarget * 10 * scale;
                if (needsScroll) {
                  return ListView(
                    children: [
                      header,
                      const Divider(height: 1),
                      if (lines.isEmpty) empty,
                      for (final line in lines)
                        Padding(
                          padding: AppSpacing.edgeInsetsLg,
                          child: _CartLineView(
                            line: line,
                            controller: controller,
                          ),
                        ),
                      const Divider(height: 1),
                      summary,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const Divider(height: 1),
                    Expanded(
                      child: lines.isEmpty
                          ? const SingleChildScrollView(child: empty)
                          : ListView.separated(
                              padding: AppSpacing.edgeInsetsLg,
                              itemCount: lines.length,
                              separatorBuilder: (_, _) => const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                child: Divider(),
                              ),
                              itemBuilder: (context, index) => _CartLineView(
                                line: lines[index],
                                controller: controller,
                              ),
                            ),
                    ),
                    const Divider(height: 1),
                    summary,
                  ],
                );
              },
            ),
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
