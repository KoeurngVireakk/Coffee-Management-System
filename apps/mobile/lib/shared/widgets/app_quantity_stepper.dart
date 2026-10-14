import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Ergonomic quantity stepper for POS cart and stock management.
///
/// Enforces a minimum 48x48dp touch target for both increment and decrement
/// buttons, tabular monospace numeric display to eliminate optical shifting,
/// and accessible screen reader semantics.
class AppQuantityStepper extends StatelessWidget {
  const AppQuantityStepper({
    super.key,
    required this.value,
    this.onIncrement,
    this.onDecrement,
    this.min = 1,
    this.max = 99,
  });

  final int value;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final int min;
  final int max;

  bool get canDecrement => value > min && onDecrement != null;
  bool get canIncrement => value < max && onIncrement != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: colorScheme.outline, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            enabled: canDecrement,
            label: 'Decrease quantity, current is $value',
            child: SizedBox(
              width: AppSpacing.minTouchTarget,
              height: AppSpacing.minTouchTarget,
              child: IconButton(
                icon: const Icon(Icons.remove_rounded, size: 18.0),
                onPressed: canDecrement ? onDecrement : null,
                tooltip: 'Decrease quantity',
                color: colorScheme.onSurface,
                disabledColor: colorScheme.outlineVariant,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 36.0),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: AppTypography.title.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Semantics(
            button: true,
            enabled: canIncrement,
            label: 'Increase quantity, current is $value',
            child: SizedBox(
              width: AppSpacing.minTouchTarget,
              height: AppSpacing.minTouchTarget,
              child: IconButton(
                icon: const Icon(Icons.add_rounded, size: 18.0),
                onPressed: canIncrement ? onIncrement : null,
                tooltip: 'Increase quantity',
                color: colorScheme.onSurface,
                disabledColor: colorScheme.outlineVariant,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
