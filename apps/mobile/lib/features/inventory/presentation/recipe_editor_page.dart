import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../pos/domain/catalog.dart';
import '../../pos/domain/catalog_repository.dart';
import '../domain/exact_quantity.dart';
import '../domain/inventory_filter.dart';
import '../domain/inventory_item.dart';
import '../domain/product_recipe.dart';
import 'inventory_controller.dart';

/// Screen for managing and replacing product ingredient recipes atomically.
class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({
    super.key,
    required this.controller,
    required this.catalogRepository,
    this.initialProduct,
  });

  final InventoryController controller;
  final CatalogRepository catalogRepository;
  final CatalogProduct? initialProduct;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  CatalogProduct? _selectedProduct;
  List<CatalogProduct> _products = const [];
  bool _isLoadingProducts = false;

  // Local working copy of recipe ingredients
  final List<RecipeIngredient> _workingIngredients = [];
  bool _hasLoadedRecipe = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    _loadProducts();
    if (_selectedProduct != null) {
      _loadRecipeForProduct(_selectedProduct!);
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final page = await widget.catalogRepository.products(page: 1);
      if (mounted) {
        setState(() {
          _products = page.items;
          _isLoadingProducts = false;
          if (_selectedProduct == null && _products.isNotEmpty) {
            _selectedProduct = _products.first;
            _loadRecipeForProduct(_products.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadRecipeForProduct(CatalogProduct product) async {
    setState(() => _hasLoadedRecipe = false);
    final recipe = await widget.controller.loadRecipe(product.id);
    if (mounted && recipe != null) {
      setState(() {
        _workingIngredients.clear();
        _workingIngredients.addAll(recipe.ingredients);
        _hasLoadedRecipe = true;
      });
    }
  }

  void _addOrEditIngredient({
    RecipeIngredient? existing,
    int? existingIndex,
  }) async {
    // Fetch active inventory items for the picker
    List<InventoryItem> availableItems = widget.controller.items
        .where((i) => i.isActive)
        .toList();
    if (availableItems.isEmpty) {
      final page = await widget.controller.repository.getItems(
        const InventoryFilter(status: 'active', perPage: 100),
      );
      availableItems = page.items;
    }

    if (!mounted) return;

    InventoryItem? selectedItem = existing != null
        ? availableItems.firstWhere(
            (i) => i.id == existing.inventoryItemId,
            orElse: () => InventoryItem(
              id: existing.inventoryItemId,
              sku: existing.sku,
              name: existing.name,
              baseUnit: existing.baseUnit,
              onHand: ExactQuantity.zero,
              reserved: ExactQuantity.zero,
              available: ExactQuantity.zero,
              reorderLevel: ExactQuantity.zero,
              isActive: existing.isActive,
              lowStock: false,
            ),
          )
        : (availableItems.isNotEmpty ? availableItems.first : null);

    if (selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active inventory items found.')),
      );
      return;
    }

    final qtyController = TextEditingController(
      text: existing != null ? existing.quantity.toReadableString() : '',
    );
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isEditing = existing != null;

          return AlertDialog(
            title: Text(isEditing ? 'Edit Ingredient' : 'Add Ingredient'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEditing) ...[
                  const Text('Select Inventory Item:'),
                  AppSpacing.gapVerticalXs,
                  DropdownButtonFormField<InventoryItem>(
                    initialValue: selectedItem,
                    isExpanded: true,
                    items: availableItems.map((item) {
                      final isAlreadyAdded = _workingIngredients.any(
                        (ing) => ing.inventoryItemId == item.id,
                      );
                      return DropdownMenuItem(
                        value: item,
                        enabled: !isAlreadyAdded,
                        child: Text(
                          '${item.name} (${item.sku})${isAlreadyAdded ? ' - Added' : ''}',
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedItem = val);
                      }
                    },
                  ),
                  AppSpacing.gapVerticalMd,
                ],
                Text(
                  'Quantity per unit sold (${selectedItem?.baseUnit.value ?? ''}):',
                ),
                AppSpacing.gapVerticalXs,
                TextField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. 18 or 180.0000',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final text = qtyController.text.trim();
                  final qty = ExactQuantity.tryParse(text);
                  if (qty == null || !qty.isPositive) {
                    setDialogState(
                      () => errorText = 'Enter a valid positive quantity.',
                    );
                    return;
                  }

                  setState(() {
                    final newIngredient = RecipeIngredient(
                      inventoryItemId: selectedItem!.id,
                      sku: selectedItem!.sku,
                      name: selectedItem!.name,
                      baseUnit: selectedItem!.baseUnit,
                      isActive: selectedItem!.isActive,
                      quantity: qty,
                    );

                    if (existingIndex != null) {
                      _workingIngredients[existingIndex] = newIngredient;
                    } else {
                      _workingIngredients.add(newIngredient);
                    }
                  });

                  Navigator.of(ctx).pop();
                },
                child: const Text('Save Ingredient'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeIngredient(int index) {
    setState(() {
      _workingIngredients.removeAt(index);
    });
  }

  Future<void> _saveRecipe() async {
    final product = _selectedProduct;
    if (product == null) return;

    if (_workingIngredients.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clear Complete Recipe?'),
          content: const Text(
            'Saving an empty recipe removes all ingredient links from this product. '
            'If inventory tracking is enabled, POS orders for this product may be rejected. Proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear Recipe'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final payloads = _workingIngredients
        .map(
          (i) => RecipeIngredientPayload(
            inventoryItemId: i.inventoryItemId,
            quantity: i.quantity,
          ),
        )
        .toList();

    final result = await widget.controller.saveRecipe(product.id, payloads);
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recipe saved for ${product.name}.'),
          backgroundColor: AppColors.successLight,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(title: const Text('Product Recipes')),
      body: SafeArea(
        child: Column(
          children: [
            // --- Product Selector Bar ---
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: _isLoadingProducts
                        ? const Center(child: AppLoadingIndicator(size: 20))
                        : DropdownButtonFormField<CatalogProduct>(
                            key: ValueKey(_selectedProduct?.id),
                            initialValue: _selectedProduct,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Product',
                              border: OutlineInputBorder(),
                            ),
                            items: _products.map((p) {
                              return DropdownMenuItem(
                                value: p,
                                child: Text('${p.name} (${p.sku})'),
                              );
                            }).toList(),
                            onChanged: (p) {
                              if (p != null) {
                                setState(() => _selectedProduct = p);
                                _loadRecipeForProduct(p);
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // --- Ingredients List ---
            Expanded(
              child: controller.isLoadingRecipe && !_hasLoadedRecipe
                  ? const Center(
                      child: AppLoadingIndicator(message: 'Loading recipe...'),
                    )
                  : _workingIngredients.isEmpty
                  ? const Center(
                      child: AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Ingredients Assigned',
                        description:
                            'Add inventory items consumed when this product is sold.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _workingIngredients.length,
                      separatorBuilder: (context, index) =>
                          AppSpacing.gapVerticalSm,
                      itemBuilder: (context, index) {
                        final ing = _workingIngredients[index];
                        return AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ing.name,
                                      style: AppTypography.title.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    AppSpacing.gapVerticalXs,
                                    Text(
                                      'SKU: ${ing.sku} · ${ing.quantity.toFormattedString()} ${ing.baseUnit.value} per unit sold',
                                      style: AppTypography.small.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit quantity',
                                onPressed: () => _addOrEditIngredient(
                                  existing: ing,
                                  existingIndex: index,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.errorLight,
                                ),
                                tooltip: 'Remove ingredient',
                                onPressed: () => _removeIngredient(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // --- Action Footer: Add Ingredient & Save ---
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Add Ingredient',
                      variant: AppButtonVariant.outline,
                      leadingIcon: Icons.add_rounded,
                      onPressed: _selectedProduct == null
                          ? null
                          : () => _addOrEditIngredient(),
                    ),
                  ),
                  AppSpacing.gapHorizontalMd,
                  Expanded(
                    child: AppButton(
                      label: controller.isSavingRecipe
                          ? 'Saving...'
                          : 'Save Recipe',
                      variant: AppButtonVariant.primary,
                      leadingIcon: Icons.save_rounded,
                      onPressed:
                          _selectedProduct == null || controller.isSavingRecipe
                          ? null
                          : _saveRecipe,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
