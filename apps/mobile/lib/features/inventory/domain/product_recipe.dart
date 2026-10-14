import 'package:flutter/foundation.dart';

import 'exact_quantity.dart';
import 'inventory_item.dart';

/// Single ingredient definition within a product recipe.
@immutable
class RecipeIngredient {
  RecipeIngredient({
    required this.inventoryItemId,
    required this.sku,
    required this.name,
    required this.baseUnit,
    required this.isActive,
    required this.quantity,
  }) {
    if (inventoryItemId <= 0) {
      throw ArgumentError('Invalid ingredient item ID: $inventoryItemId');
    }
    if (sku.trim().isEmpty) {
      throw ArgumentError('Ingredient SKU cannot be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Ingredient name cannot be empty.');
    }
    if (!quantity.isPositive) {
      throw ArgumentError('Recipe ingredient quantity must be positive.');
    }
  }

  final int inventoryItemId;
  final String sku;
  final String name;
  final BaseUnit baseUnit;
  final bool isActive;
  final ExactQuantity quantity;

  RecipeIngredient copyWith({
    int? inventoryItemId,
    String? sku,
    String? name,
    BaseUnit? baseUnit,
    bool? isActive,
    ExactQuantity? quantity,
  }) {
    return RecipeIngredient(
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      baseUnit: baseUnit ?? this.baseUnit,
      isActive: isActive ?? this.isActive,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeIngredient &&
          other.inventoryItemId == inventoryItemId &&
          other.sku == sku &&
          other.name == name &&
          other.baseUnit == baseUnit &&
          other.isActive == isActive &&
          other.quantity == quantity);

  @override
  int get hashCode =>
      Object.hash(inventoryItemId, sku, name, baseUnit, isActive, quantity);

  @override
  String toString() =>
      'RecipeIngredient(item: $inventoryItemId, sku: $sku, qty: ${quantity.toCanonicalString()} ${baseUnit.value})';
}

/// Complete recipe for a sellable product.
@immutable
class ProductRecipe {
  ProductRecipe({
    required this.productId,
    required List<RecipeIngredient> ingredients,
  }) : ingredients = List.unmodifiable(ingredients) {
    if (productId <= 0) {
      throw ArgumentError('Invalid product ID: $productId');
    }
    if (ingredients.length > 100) {
      throw ArgumentError('A recipe may contain at most 100 ingredients.');
    }
    final itemIds = <int>{};
    for (final ingredient in ingredients) {
      if (!itemIds.add(ingredient.inventoryItemId)) {
        throw ArgumentError(
          'Duplicate ingredient ID in recipe: ${ingredient.inventoryItemId}',
        );
      }
    }
  }

  final int productId;
  final List<RecipeIngredient> ingredients;

  bool get isEmpty => ingredients.isEmpty;
  bool get isNotEmpty => ingredients.isNotEmpty;
  int get count => ingredients.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductRecipe &&
          other.productId == productId &&
          listEquals(other.ingredients, ingredients));

  @override
  int get hashCode => Object.hash(productId, Object.hashAll(ingredients));
}

/// Payload item for atomic recipe replacement (`PUT /api/v1/products/{id}/recipe`).
@immutable
class RecipeIngredientPayload {
  RecipeIngredientPayload({
    required this.inventoryItemId,
    required this.quantity,
  }) {
    if (inventoryItemId <= 0) {
      throw ArgumentError(
        'Invalid ingredient inventory item ID: $inventoryItemId',
      );
    }
    if (!quantity.isPositive) {
      throw ArgumentError('Recipe ingredient quantity must be positive.');
    }
  }

  final int inventoryItemId;
  final ExactQuantity quantity;

  Map<String, dynamic> toJson() => {
    'inventory_item_id': inventoryItemId,
    'quantity': quantity.toCanonicalString(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeIngredientPayload &&
          other.inventoryItemId == inventoryItemId &&
          other.quantity == quantity);

  @override
  int get hashCode => Object.hash(inventoryItemId, quantity);
}
