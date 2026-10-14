import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/exact_quantity.dart';
import '../../domain/inventory_item.dart';
import '../../domain/stock_movement.dart';
import '../inventory_controller.dart';

/// Modal dialog for recording manual stock movements with idempotency protection.
class StockMovementDialog extends StatefulWidget {
  const StockMovementDialog({
    super.key,
    required this.item,
    required this.controller,
  });

  final InventoryItem item;
  final InventoryController controller;

  @override
  State<StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends State<StockMovementDialog> {
  StockMovementReason _reason = StockMovementReason.receipt;
  bool _isAdjustmentPositive = true;

  late final TextEditingController _quantityController;
  late final TextEditingController _noteController;

  String? _quantityError;
  String? _noteError;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() async {
    setState(() {
      _quantityError = null;
      _noteError = null;
    });

    final qtyStr = _quantityController.text.trim();
    if (qtyStr.isEmpty) {
      setState(() => _quantityError = 'Please enter a quantity.');
      return;
    }

    final parsed = ExactQuantity.tryParse(qtyStr);
    if (parsed == null || parsed.isZero) {
      setState(
        () => _quantityError =
            'Enter a valid positive quantity up to 4 decimal places.',
      );
      return;
    }

    final note = _noteController.text.trim();
    if (_reason == StockMovementReason.adjustment && note.isEmpty) {
      setState(
        () => _noteError = 'An explanatory note is required for adjustments.',
      );
      return;
    }
    if (note.length > 500) {
      setState(() => _noteError = 'Note must be at most 500 characters.');
      return;
    }

    // Determine signed delta based on reason
    ExactQuantity delta;
    switch (_reason) {
      case StockMovementReason.openingBalance:
      case StockMovementReason.receipt:
        delta = parsed;
        break;
      case StockMovementReason.waste:
        delta = -parsed;
        break;
      case StockMovementReason.adjustment:
        delta = _isAdjustmentPositive ? parsed : -parsed;
        break;
      case StockMovementReason.sale:
        return;
    }

    final result = await widget.controller.createMovement(
      inventoryItemId: widget.item.id,
      reason: _reason,
      quantityDelta: delta,
      note: note.isEmpty ? null : note,
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock movement recorded: ${delta.toCanonicalString()} ${widget.item.baseUnit.value}',
          ),
          backgroundColor: AppColors.successLight,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isBusy = controller.isSubmittingMovement;
        final isUncertain = controller.isMovementUncertain;
        final failure = controller.movementFailure;

        return AlertDialog(
          title: Text(
            'Record Stock Movement',
            style: AppTypography.title.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Item Context Header ---
                  Text(
                    '${widget.item.name} (${widget.item.sku})',
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Current Available: ${widget.item.available.formatWithUnit(widget.item.baseUnit.value)}',
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  AppSpacing.gapVerticalMd,

                  // --- Uncertain State Banner ---
                  if (isUncertain) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: theme.colorScheme.error,
                              ),
                              AppSpacing.gapHorizontalXs,
                              Text(
                                'Uncertain Network Outcome',
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapVerticalXs,
                          Text(
                            'The server may have recorded this movement. Retry will reuse the identical Idempotency-Key to prevent duplicate changes.',
                            style: AppTypography.small.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          AppSpacing.gapVerticalSm,
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'Safe Retry',
                                  variant: AppButtonVariant.primary,
                                  onPressed: isBusy
                                      ? null
                                      : () =>
                                            controller.retryUncertainMovement(),
                                ),
                              ),
                              AppSpacing.gapHorizontalSm,
                              Expanded(
                                child: AppButton(
                                  label: 'Dismiss',
                                  variant: AppButtonVariant.outline,
                                  onPressed: isBusy
                                      ? null
                                      : () =>
                                            controller.clearUncertainMovement(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapVerticalMd,
                  ],

                  // --- Reason Selector ---
                  Text('Movement Reason', style: AppTypography.small),
                  AppSpacing.gapVerticalXs,
                  DropdownButtonFormField<StockMovementReason>(
                    initialValue: _reason,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items:
                        [
                          StockMovementReason.receipt,
                          StockMovementReason.waste,
                          StockMovementReason.adjustment,
                          StockMovementReason.openingBalance,
                        ].map((reason) {
                          return DropdownMenuItem(
                            value: reason,
                            child: Text(reason.label),
                          );
                        }).toList(),
                    onChanged: isBusy || isUncertain
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => _reason = val);
                            }
                          },
                  ),
                  AppSpacing.gapVerticalSm,

                  // --- Adjustment Direction Toggle (if reason is adjustment) ---
                  if (_reason == StockMovementReason.adjustment) ...[
                    Text('Adjustment Direction', style: AppTypography.small),
                    AppSpacing.gapVerticalXs,
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('+ Increase Stock'),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('- Decrease Stock'),
                        ),
                      ],
                      selected: {_isAdjustmentPositive},
                      onSelectionChanged: isBusy || isUncertain
                          ? null
                          : (selection) {
                              setState(
                                () => _isAdjustmentPositive = selection.first,
                              );
                            },
                    ),
                    AppSpacing.gapVerticalSm,
                  ],

                  // --- Quantity Input ---
                  Text(
                    'Quantity (${widget.item.baseUnit.value})',
                    style: AppTypography.small,
                  ),
                  AppSpacing.gapVerticalXs,
                  TextField(
                    controller: _quantityController,
                    enabled: !isBusy && !isUncertain,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 500 or 12.5000',
                      border: const OutlineInputBorder(),
                      errorText: _quantityError,
                      prefixText:
                          _reason == StockMovementReason.waste ||
                              (_reason == StockMovementReason.adjustment &&
                                  !_isAdjustmentPositive)
                          ? '- '
                          : '+ ',
                    ),
                  ),
                  AppSpacing.gapVerticalSm,

                  // --- Note Input ---
                  Text(
                    'Explanatory Note ${_reason == StockMovementReason.adjustment ? '(Required)' : '(Optional)'}',
                    style: AppTypography.small,
                  ),
                  AppSpacing.gapVerticalXs,
                  TextField(
                    controller: _noteController,
                    enabled: !isBusy && !isUncertain,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Reason for adjustment / delivery reference',
                      border: const OutlineInputBorder(),
                      errorText: _noteError,
                    ),
                  ),

                  // --- Failure message ---
                  if (failure != null && !isUncertain) ...[
                    AppSpacing.gapVerticalSm,
                    Text(
                      failure.message,
                      style: AppTypography.small.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isBusy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            AppButton(
              label: isBusy ? 'Submitting...' : 'Record Movement',
              variant: AppButtonVariant.primary,
              onPressed: isBusy || isUncertain ? null : _validateAndSubmit,
            ),
          ],
        );
      },
    );
  }
}
