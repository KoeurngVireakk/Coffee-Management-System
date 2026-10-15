import 'package:flutter/material.dart';

import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/cafe_theme_extension.dart';
import '../../../shared/theme/formatters.dart';
import '../domain/catalog.dart';
import 'pos_category_art.dart';

/// Text-first menu tile with one add action and an exact, immediate unit price.
class PosProductCard extends StatefulWidget {
  const PosProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.onAdd,
  });
  final CatalogProduct product;
  final int quantity;
  final VoidCallback? onAdd;

  @override
  State<PosProductCard> createState() => _PosProductCardState();
}

class _PosProductCardState extends State<PosProductCard> {
  bool _focused = false;
  CatalogProduct get product => widget.product;
  int get quantity => widget.quantity;
  VoidCallback? get onAdd => widget.onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cafe = CafeThemeExtension.of(context);
    final price = Formatters.formatCents(product.priceMinor);
    final selected = quantity > 0;
    final categoryColor = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: onAdd != null,
      label: onAdd == null
          ? '${product.name}, $price USD, ${product.category.name}. Selection locked while the order is in progress.'
          : 'Add ${product.name}, $price USD, ${product.category.name}. $quantity in cart',
      onTap: onAdd,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        animationDuration: AppMotion.respectingPreferences(
          context,
          AppMotion.tabSelection,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusXl,
          side: BorderSide(
            color: selected || _focused
                ? colors.primary
                : colors.outlineVariant,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          onFocusChange: (value) {
            if (_focused != value) setState(() => _focused = value);
          },
          focusColor: colors.primary.withValues(alpha: .18),
          hoverColor: colors.primary.withValues(alpha: .06),
          child: Padding(
            padding: AppSpacing.edgeInsetsMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      posCategoryIcon(product.category.name),
                      size: 22,
                      color: categoryColor,
                    ),
                    AppSpacing.gapHorizontalSm,
                    Expanded(
                      child: Text(
                        product.category.name,
                        style: AppTypography.small.copyWith(
                          fontSize: 12,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: AppSpacing.s),
                      AnimatedSwitcher(
                        key: ValueKey('product-quantity-${product.id}'),
                        duration: AppMotion.respectingPreferences(
                          context,
                          AppMotion.hoverFocus,
                        ),
                        child: Container(
                          key: ValueKey(quantity),
                          constraints: const BoxConstraints(minWidth: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: AppRadius.radiusSm,
                          ),
                          child: Text(
                            '$quantity',
                            textAlign: TextAlign.center,
                            style: AppTypography.label.copyWith(
                              color: colors.onPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                AppSpacing.gapVerticalMd,
                Text(
                  product.name,
                  style: AppTypography.bodyLarge.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AppSpacing.gapVerticalSm,
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.s,
                    children: [
                      Text(
                        price,
                        style: AppTypography.price.copyWith(
                          fontSize: 20,
                          color: cafe.priceColor,
                        ),
                      ),
                      Container(
                        width: AppSpacing.minTouchTarget,
                        height: AppSpacing.minTouchTarget,
                        decoration: BoxDecoration(
                          color: onAdd == null
                              ? colors.outlineVariant
                              : colors.primaryContainer,
                          borderRadius: AppRadius.radiusLg,
                          border: Border.all(
                            color: onAdd == null
                                ? colors.outlineVariant
                                : colors.primary,
                          ),
                        ),
                        child: Icon(
                          onAdd == null ? Icons.lock_outline : Icons.add,
                          color: onAdd == null
                              ? colors.onSurfaceVariant
                              : colors.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onAdd == null) ...[
                  AppSpacing.gapVerticalXs,
                  Text(
                    'Order in progress',
                    style: AppTypography.small.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
