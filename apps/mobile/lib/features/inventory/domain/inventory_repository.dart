import 'package:flutter/foundation.dart';

import 'exact_quantity.dart';
import 'inventory_filter.dart';
import 'inventory_item.dart';
import 'product_recipe.dart';
import 'stock_movement.dart';

/// Immutable page of inventory items.
@immutable
class InventoryPage {
  InventoryPage({
    required List<InventoryItem> items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  }) : items = List.unmodifiable(items);

  final List<InventoryItem> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage && currentPage < 10000;
}

/// Immutable page of stock movements.
@immutable
class StockMovementPage {
  StockMovementPage({
    required List<StockMovement> items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  }) : items = List.unmodifiable(items);

  final List<StockMovement> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage && currentPage < 10000;
}

enum InventoryFailureKind {
  sessionExpired,
  forbidden,
  notFound,
  conflict,
  validation,
  rateLimited,
  network,
  server,
  invalidResponse,
}

/// Typed failure for inventory operations.
class InventoryFailure implements Exception {
  const InventoryFailure(
    this.kind, {
    this.detail,
    this.errors = const {},
    this.retryAfterSeconds,
  });

  final InventoryFailureKind kind;
  final String? detail;
  final Map<String, List<String>> errors;
  final int? retryAfterSeconds;

  String? fieldMessage(String field) => errors[field]?.firstOrNull;

  String get message => switch (kind) {
    InventoryFailureKind.sessionExpired =>
      'Your session has expired. Please sign in again.',
    InventoryFailureKind.forbidden =>
      'You do not have permission to perform this inventory action.',
    InventoryFailureKind.notFound =>
      'The requested inventory item or recipe does not exist.',
    InventoryFailureKind.conflict =>
      detail ?? 'Inventory state changed or conflict occurred. Please refresh.',
    InventoryFailureKind.validation =>
      detail ??
          fieldMessage('sku') ??
          fieldMessage('name') ??
          fieldMessage('base_unit') ??
          fieldMessage('reorder_level') ??
          fieldMessage('quantity_delta') ??
          fieldMessage('reason') ??
          fieldMessage('note') ??
          fieldMessage('ingredients') ??
          'Invalid inventory data. Please check your inputs.',
    InventoryFailureKind.rateLimited =>
      'Too many requests. Please wait before retrying.',
    InventoryFailureKind.network =>
      'Unable to connect to the server. Check your network connection.',
    InventoryFailureKind.server =>
      'The inventory service encountered an error. Please try again shortly.',
    InventoryFailureKind.invalidResponse =>
      'Received an invalid response from the server.',
  };

  @override
  String toString() => 'InventoryFailure($kind: $message)';
}

/// Abstract contract for inventory items, stock movements, and product recipes.
abstract interface class InventoryRepository {
  /// Fetches a paginated list of inventory items matching filter criteria.
  Future<InventoryPage> getItems(InventoryFilter filter);

  /// Fetches authoritative single inventory item details.
  Future<InventoryItem> getItem(int id);

  /// Creates a new inventory item with zero starting stock.
  Future<InventoryItem> createItem({
    required String sku,
    required String name,
    required BaseUnit baseUnit,
    ExactQuantity? reorderLevel,
    bool isActive = true,
  });

  /// Updates allowed inventory item metadata (SKU, name, reorder_level, is_active).
  Future<InventoryItem> updateItem(
    int id, {
    String? sku,
    String? name,
    ExactQuantity? reorderLevel,
    bool? isActive,
  });

  /// Fetches the append-only stock movement ledger for an item.
  Future<StockMovementPage> getMovements(
    int itemId, {
    int page = 1,
    int perPage = 25,
  });

  /// Appends an audited manual movement to the stock ledger.
  Future<StockMovement> createMovement(StockMovementIntent intent);

  /// Fetches the current product recipe.
  Future<ProductRecipe> getRecipe(int productId);

  /// Atomically replaces the product recipe ingredients.
  Future<ProductRecipe> replaceRecipe(
    int productId,
    List<RecipeIngredientPayload> ingredients,
  );
}
