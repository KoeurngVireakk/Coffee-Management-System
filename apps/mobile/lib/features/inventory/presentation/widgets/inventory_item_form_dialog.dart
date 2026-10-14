import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/exact_quantity.dart';
import '../../domain/inventory_item.dart';
import '../inventory_controller.dart';

/// Modal dialog for creating or updating inventory item metadata.
class InventoryItemFormDialog extends StatefulWidget {
  const InventoryItemFormDialog({
    super.key,
    this.item,
    required this.controller,
  });

  final InventoryItem? item;
  final InventoryController controller;

  bool get isEditing => item != null;

  @override
  State<InventoryItemFormDialog> createState() =>
      _InventoryItemFormDialogState();
}

class _InventoryItemFormDialogState extends State<InventoryItemFormDialog> {
  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _reorderController;

  BaseUnit _baseUnit = BaseUnit.g;
  bool _isActive = true;

  String? _skuError;
  String? _nameError;
  String? _reorderError;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _skuController = TextEditingController(text: item?.sku ?? '');
    _nameController = TextEditingController(text: item?.name ?? '');
    _reorderController = TextEditingController(
      text: item != null && !item.reorderLevel.isZero
          ? item.reorderLevel.toReadableString()
          : '',
    );
    if (item != null) {
      _baseUnit = item.baseUnit;
      _isActive = item.isActive;
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _skuError = null;
      _nameError = null;
      _reorderError = null;
    });

    final sku = _skuController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final reorderStr = _reorderController.text.trim();

    if (sku.isEmpty) {
      setState(() => _skuError = 'SKU is required.');
      return;
    }
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]*$').hasMatch(sku) || sku.length > 64) {
      setState(
        () => _skuError =
            'SKU must be uppercase alphanumeric with dashes/underscores (max 64).',
      );
      return;
    }

    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required.');
      return;
    }
    if (name.length > 160) {
      setState(() => _nameError = 'Name must be at most 160 characters.');
      return;
    }

    ExactQuantity? reorderLevel;
    if (reorderStr.isNotEmpty) {
      reorderLevel = ExactQuantity.tryParse(reorderStr);
      if (reorderLevel == null) {
        setState(() => _reorderError = 'Enter a valid nonnegative quantity.');
        return;
      }
    }

    // Retirement confirmation if active is changing from true to false
    if (widget.isEditing && widget.item!.isActive && !_isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Item Retirement'),
          content: const Text(
            'Retiring this inventory item will prevent it from being used in new recipes and hide it from active stock lists. '
            'Historical movement ledgers, sales records, and reservations remain intact. Proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Retire Item'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (widget.isEditing) {
      final updated = await widget.controller.updateItem(
        widget.item!.id,
        sku: sku != widget.item!.sku ? sku : null,
        name: name != widget.item!.name ? name : null,
        reorderLevel: reorderLevel != widget.item!.reorderLevel
            ? reorderLevel
            : null,
        isActive: _isActive != widget.item!.isActive ? _isActive : null,
      );
      if (updated != null && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory item updated successfully.'),
            backgroundColor: AppColors.successLight,
          ),
        );
      }
    } else {
      final created = await widget.controller.createItem(
        sku: sku,
        name: name,
        baseUnit: _baseUnit,
        reorderLevel: reorderLevel,
        isActive: _isActive,
      );
      if (created != null && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory item created successfully.'),
            backgroundColor: AppColors.successLight,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isBusy = widget.isEditing
            ? controller.isUpdating
            : controller.isCreating;
        final failure = widget.isEditing
            ? controller.updateFailure
            : controller.createFailure;

        return AlertDialog(
          title: Text(
            widget.isEditing ? 'Edit Inventory Item' : 'New Inventory Item',
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
                  // --- SKU Field ---
                  Text('SKU', style: AppTypography.small),
                  AppSpacing.gapVerticalXs,
                  TextField(
                    controller: _skuController,
                    enabled: !isBusy,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. BEANS or MILK_WHOLE',
                      border: const OutlineInputBorder(),
                      errorText: _skuError ?? failure?.fieldMessage('sku'),
                    ),
                  ),
                  AppSpacing.gapVerticalSm,

                  // --- Name Field ---
                  Text('Name', style: AppTypography.small),
                  AppSpacing.gapVerticalXs,
                  TextField(
                    controller: _nameController,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      hintText: 'e.g. Coffee Beans Arabica',
                      border: const OutlineInputBorder(),
                      errorText: _nameError ?? failure?.fieldMessage('name'),
                    ),
                  ),
                  AppSpacing.gapVerticalSm,

                  // --- Base Unit Field ---
                  Text('Base Unit', style: AppTypography.small),
                  AppSpacing.gapVerticalXs,
                  if (widget.isEditing)
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        helperText: 'Base unit is immutable after creation.',
                      ),
                      child: Text(
                        widget.item!.baseUnit.label,
                        style: AppTypography.body,
                      ),
                    )
                  else
                    DropdownButtonFormField<BaseUnit>(
                      initialValue: _baseUnit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: failure?.fieldMessage('base_unit'),
                      ),
                      items: BaseUnit.values.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text('${unit.label} (${unit.value})'),
                        );
                      }).toList(),
                      onChanged: isBusy
                          ? null
                          : (val) {
                              if (val != null) setState(() => _baseUnit = val);
                            },
                    ),
                  AppSpacing.gapVerticalSm,

                  // --- Reorder Level Field ---
                  Text(
                    'Reorder Level (Optional Threshold)',
                    style: AppTypography.small,
                  ),
                  AppSpacing.gapVerticalXs,
                  TextField(
                    controller: _reorderController,
                    enabled: !isBusy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 1000 or 50.0000',
                      border: const OutlineInputBorder(),
                      errorText:
                          _reorderError ??
                          failure?.fieldMessage('reorder_level'),
                    ),
                  ),
                  AppSpacing.gapVerticalSm,

                  // --- Active Switch ---
                  SwitchListTile(
                    title: const Text('Active Status'),
                    subtitle: Text(
                      _isActive
                          ? 'Available for new recipes and standard operations.'
                          : 'Retired / Inactive.',
                      style: AppTypography.small,
                    ),
                    value: _isActive,
                    onChanged: isBusy
                        ? null
                        : (val) => setState(() => _isActive = val),
                    contentPadding: EdgeInsets.zero,
                  ),

                  // General failure message
                  if (failure != null) ...[
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
              label: isBusy
                  ? 'Saving...'
                  : (widget.isEditing ? 'Save Changes' : 'Create Item'),
              variant: AppButtonVariant.primary,
              onPressed: isBusy ? null : _handleSubmit,
            ),
          ],
        );
      },
    );
  }
}
