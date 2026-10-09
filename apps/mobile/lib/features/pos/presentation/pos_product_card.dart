import 'package:flutter/material.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/cafe_theme_extension.dart';
import '../../../shared/theme/formatters.dart';
import '../domain/catalog.dart';

class PosProductCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cafe = CafeThemeExtension.of(context);
    final price = Formatters.formatCents(product.priceMinor);
    return Semantics(
      button: true,
      enabled: onAdd != null,
      label: onAdd == null
          ? '${product.name}, $price USD, ${product.category.name}. Selection locked while the order is in progress.'
          : 'Add ${product.name}, $price USD, ${product.category.name}. $quantity in cart',
      onTap: onAdd,
      excludeSemantics: true,
      child: Material(
        color: cafe.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusXl,
          side: BorderSide(
            color: quantity > 0 ? colors.secondary : cafe.borderSubtle,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          focusColor: colors.secondary.withValues(alpha: 0.2),
          child: Padding(
            padding: AppSpacing.edgeInsetsLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: AppSpacing.edgeInsetsMd,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: AppRadius.radiusMd,
                  ),
                  // Presentation only; the catalog has no product image contract.
                  child: Icon(
                    Icons.local_cafe_outlined,
                    color: colors.onSecondaryContainer,
                    size: 28,
                  ),
                ),
                AppSpacing.gapVerticalLg,
                Text(
                  product.name,
                  style: AppTypography.title.copyWith(color: colors.onSurface),
                ),
                AppSpacing.gapVerticalXs,
                Text(
                  product.category.name,
                  style: AppTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapVerticalMd,
                Text(
                  price,
                  style: AppTypography.price.copyWith(color: cafe.priceColor),
                ),
                AppSpacing.gapVerticalSm,
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      onAdd == null
                          ? Icons.lock_outline
                          : quantity > 0
                          ? Icons.check_circle_outline
                          : Icons.add_circle_outline,
                      color: onAdd == null
                          ? colors.onSurfaceVariant
                          : colors.secondary,
                      size: 24,
                    ),
                    Text(
                      onAdd == null
                          ? 'Order in progress'
                          : quantity > 0
                          ? '$quantity in order · Add'
                          : 'Add to order',
                      style: AppTypography.label.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
