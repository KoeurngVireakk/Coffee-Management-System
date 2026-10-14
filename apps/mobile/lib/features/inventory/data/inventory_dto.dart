import '../../pos/data/catalog_dto.dart';
import '../domain/exact_quantity.dart';
import '../domain/inventory_item.dart';
import '../domain/inventory_repository.dart';
import '../domain/product_recipe.dart';
import '../domain/stock_movement.dart';

/// Strict DTO decoding for inventory resources.
///
/// Fails closed if expected fields are absent, null where not allowed, or have
/// invalid quantities.
abstract final class InventoryDto {
  static Map<String, dynamic> _extractData(Object? value) {
    final map = CatalogDto.object(value);
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected "data" object envelope.');
    }
    return data;
  }

  /// Decodes single [InventoryItem] from either wrapped or unwrapped JSON.
  static InventoryItem item(Object? value) {
    final json =
        value is Map<String, dynamic> &&
            value.containsKey('data') &&
            value['data'] is Map<String, dynamic>
        ? value['data'] as Map<String, dynamic>
        : CatalogDto.object(value);

    final id = CatalogDto.integer(json['id']);
    final sku = CatalogDto.text(json['sku'], 64);
    final name = CatalogDto.text(json['name'], 160);
    final baseUnitRaw = CatalogDto.text(json['base_unit'], 16);
    final baseUnit = BaseUnit.parse(baseUnitRaw);

    final onHandStr = json['on_hand'];
    final reservedStr = json['reserved'];
    final availableStr = json['available'];
    final reorderLevelStr = json['reorder_level'];

    if (onHandStr is! String ||
        reservedStr is! String ||
        availableStr is! String ||
        reorderLevelStr is! String) {
      throw const FormatException(
        'Inventory balances must be string quantities.',
      );
    }

    final onHand = ExactQuantity.parse(onHandStr, signed: false);
    final reserved = ExactQuantity.parse(reservedStr, signed: false);
    // available can theoretically be negative if on_hand < reserved in edge cases
    final available = ExactQuantity.parse(availableStr, signed: true);
    final reorderLevel = ExactQuantity.parse(reorderLevelStr, signed: false);

    final isActive = CatalogDto.flag(json['is_active']);
    final lowStock = CatalogDto.flag(json['low_stock']);

    DateTime? createdAt;
    if (json['created_at'] != null) {
      if (json['created_at'] is! String) {
        throw const FormatException('Invalid created_at timestamp.');
      }
      createdAt = DateTime.tryParse(json['created_at'] as String);
    }

    DateTime? updatedAt;
    if (json['updated_at'] != null) {
      if (json['updated_at'] is! String) {
        throw const FormatException('Invalid updated_at timestamp.');
      }
      updatedAt = DateTime.tryParse(json['updated_at'] as String);
    }

    return InventoryItem(
      id: id,
      sku: sku,
      name: name,
      baseUnit: baseUnit,
      onHand: onHand,
      reserved: reserved,
      available: available,
      reorderLevel: reorderLevel,
      isActive: isActive,
      lowStock: lowStock,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Decodes paginated [InventoryPage].
  static InventoryPage itemPage(
    Object? value, {
    required int requestedPage,
    required int requestedPerPage,
  }) {
    final page = CatalogDto.page(
      value,
      item,
      requestedPage: requestedPage,
      requestedPerPage: requestedPerPage,
    );

    final ids = <int>{};
    for (final item in page.items) {
      if (!ids.add(item.id)) {
        throw const FormatException(
          'Duplicate inventory item ID in page data.',
        );
      }
    }

    return InventoryPage(
      items: page.items,
      currentPage: page.currentPage,
      lastPage: page.lastPage,
      perPage: page.perPage,
      total: page.total,
    );
  }

  /// Decodes single [StockMovement].
  static StockMovement movement(Object? value) {
    final json =
        value is Map<String, dynamic> &&
            value.containsKey('data') &&
            value['data'] is Map<String, dynamic>
        ? value['data'] as Map<String, dynamic>
        : CatalogDto.object(value);

    final id = CatalogDto.integer(json['id']);
    final inventoryItemId = CatalogDto.integer(json['inventory_item_id']);

    int? orderId;
    if (json['order_id'] != null) {
      orderId = CatalogDto.integer(json['order_id']);
    }

    int? actorId;
    if (json['actor_id'] != null) {
      actorId = CatalogDto.integer(json['actor_id']);
    }

    final deltaStr = json['quantity_delta'];
    if (deltaStr is! String) {
      throw const FormatException('Movement quantity_delta must be a string.');
    }
    final quantityDelta = ExactQuantity.parse(deltaStr, signed: true);

    final reasonStr = CatalogDto.text(json['reason'], 32);
    final reason = StockMovementReason.parse(reasonStr);

    String? note;
    if (json['note'] != null) {
      if (json['note'] is! String) {
        throw const FormatException('Movement note must be a string.');
      }
      note = json['note'] as String;
    }

    DateTime? createdAt;
    if (json['created_at'] != null) {
      if (json['created_at'] is! String) {
        throw const FormatException('Invalid created_at timestamp.');
      }
      createdAt = DateTime.tryParse(json['created_at'] as String);
    }

    return StockMovement(
      id: id,
      inventoryItemId: inventoryItemId,
      orderId: orderId,
      actorId: actorId,
      quantityDelta: quantityDelta,
      reason: reason,
      note: note,
      createdAt: createdAt,
    );
  }

  /// Decodes paginated [StockMovementPage].
  static StockMovementPage movementPage(
    Object? value, {
    required int requestedPage,
    required int requestedPerPage,
  }) {
    final page = CatalogDto.page(
      value,
      movement,
      requestedPage: requestedPage,
      requestedPerPage: requestedPerPage,
    );

    final ids = <int>{};
    for (final m in page.items) {
      if (!ids.add(m.id)) {
        throw const FormatException(
          'Duplicate stock movement ID in page data.',
        );
      }
    }

    return StockMovementPage(
      items: page.items,
      currentPage: page.currentPage,
      lastPage: page.lastPage,
      perPage: page.perPage,
      total: page.total,
    );
  }

  /// Decodes [ProductRecipe].
  static ProductRecipe recipe(Object? value) {
    final json = _extractData(value);
    final productId = CatalogDto.integer(json['product_id']);

    final rawIngredients = json['ingredients'];
    if (rawIngredients is! List) {
      throw const FormatException('Recipe ingredients must be a list.');
    }

    final ingredients = <RecipeIngredient>[];
    for (final raw in rawIngredients) {
      final ingJson = CatalogDto.object(raw);
      final itemId = CatalogDto.integer(ingJson['inventory_item_id']);
      final sku = CatalogDto.text(ingJson['sku'], 64);
      final name = CatalogDto.text(ingJson['name'], 160);
      final baseUnit = BaseUnit.parse(
        CatalogDto.text(ingJson['base_unit'], 16),
      );
      final isActive = CatalogDto.flag(ingJson['is_active']);

      final qtyStr = ingJson['quantity'];
      if (qtyStr is! String) {
        throw const FormatException('Ingredient quantity must be a string.');
      }
      final quantity = ExactQuantity.parse(qtyStr, signed: false);

      ingredients.add(
        RecipeIngredient(
          inventoryItemId: itemId,
          sku: sku,
          name: name,
          baseUnit: baseUnit,
          isActive: isActive,
          quantity: quantity,
        ),
      );
    }

    return ProductRecipe(productId: productId, ingredients: ingredients);
  }
}
