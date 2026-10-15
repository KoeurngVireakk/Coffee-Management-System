import 'package:flutter/material.dart';

import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/formatters.dart';
import 'pos_controller.dart';

/// Allocated below the catalog, never painted over products or navigation.
class PosCartSummary extends StatelessWidget {
  const PosCartSummary({
    super.key,
    required this.controller,
    required this.onPressed,
  });
  final PosController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final order = controller.checkout?.state.order;
    final count = order?.itemCount ?? controller.cart.itemCount;
    final amount = order?.totalMinor ?? controller.cart.subtotalMinor;
    final label =
        '${order == null ? 'View cart' : 'View order'} · $count ${count == 1 ? 'item' : 'items'}';
    final large = MediaQuery.textScalerOf(context).scale(14) > 19;
    final labelText = Text(
      label,
      style: AppTypography.label.copyWith(
        color: colors.onPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
    // Amount changes are authoritative and immediate, never animated or tweened.
    final total = Text(
      '${Formatters.formatCents(amount)} USD',
      style: AppTypography.price.copyWith(
        color: colors.onPrimary,
        fontSize: 16,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Semantics(
        liveRegion: true,
        child: FilledButton(
          key: const ValueKey('open-cart'),
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            padding: AppSpacing.edgeInsetsMd,
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusLg,
            ),
          ),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [labelText, AppSpacing.gapVerticalXs, total],
                )
              : Row(
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 28,
                        child: AnimatedSwitcher(
                          duration: order == null
                              ? AppMotion.respectingPreferences(
                                  context,
                                  AppMotion.hoverFocus,
                                )
                              : Duration.zero,
                          child: count == 0
                              ? const Icon(
                                  Icons.shopping_bag_outlined,
                                  key: ValueKey(0),
                                  size: 22,
                                )
                              : FittedBox(
                                  key: ValueKey(count),
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$count',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: colors.onPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    AppSpacing.gapHorizontalSm,
                    Expanded(child: labelText),
                    AppSpacing.gapHorizontalSm,
                    total,
                    AppSpacing.gapHorizontalSm,
                    const ExcludeSemantics(
                      child: Icon(Icons.arrow_forward, size: 18),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
