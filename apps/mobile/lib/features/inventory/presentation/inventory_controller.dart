import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../pos/domain/catalog_repository.dart';
import '../../pos/domain/checkout_intent.dart';
import '../domain/exact_quantity.dart';
import '../domain/inventory_filter.dart';
import '../domain/inventory_item.dart';
import '../domain/inventory_repository.dart';
import '../domain/product_recipe.dart';
import '../domain/stock_movement.dart';

/// Presentation state machine managing inventory listing, search, filtering,
/// detail views, stock movements, and product recipes.
class InventoryController extends ChangeNotifier {
  InventoryController({
    required this.repository,
    this.catalogRepository,
    this.onSessionExpired,
    String Function()? keyGenerator,
  }) : _keyGenerator = keyGenerator ?? OperationKey.generate;

  final InventoryRepository repository;
  final CatalogRepository? catalogRepository;
  final VoidCallback? onSessionExpired;
  final String Function() _keyGenerator;

  bool _disposed = false;
  int _generation = 0;
  Timer? _searchDebounceTimer;

  // --- List State ---
  InventoryFilter _filter = InventoryFilter.initial;
  List<InventoryItem> _items = const [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _total = 0;
  InventoryFailure? _listFailure;
  InventoryFailure? _loadMoreFailure;

  // --- Selected Item State ---
  InventoryItem? _selectedItem;
  bool _isLoadingItem = false;
  InventoryFailure? _itemFailure;

  // --- CRUD Operation State ---
  bool _isCreating = false;
  InventoryFailure? _createFailure;
  bool _isUpdating = false;
  InventoryFailure? _updateFailure;

  // --- Stock Movement State ---
  bool _isSubmittingMovement = false;
  InventoryFailure? _movementFailure;
  StockMovement? _lastMovementSuccess;
  StockMovementIntent? _pendingMovementIntent;
  bool _isMovementUncertain = false;

  // --- Movement History State ---
  List<StockMovement> _movements = const [];
  int _movementsPage = 1;
  bool _hasMoreMovements = false;
  bool _isLoadingMovements = false;
  InventoryFailure? _movementsFailure;

  // --- Recipe Editor State ---
  ProductRecipe? _currentRecipe;
  bool _isLoadingRecipe = false;
  bool _isSavingRecipe = false;
  InventoryFailure? _recipeFailure;

  // --- Getters ---
  InventoryFilter get filter => _filter;
  List<InventoryItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get total => _total;
  InventoryFailure? get listFailure => _listFailure;
  InventoryFailure? get loadMoreFailure => _loadMoreFailure;

  InventoryItem? get selectedItem => _selectedItem;
  bool get isLoadingItem => _isLoadingItem;
  InventoryFailure? get itemFailure => _itemFailure;

  bool get isCreating => _isCreating;
  InventoryFailure? get createFailure => _createFailure;
  bool get isUpdating => _isUpdating;
  InventoryFailure? get updateFailure => _updateFailure;

  bool get isSubmittingMovement => _isSubmittingMovement;
  InventoryFailure? get movementFailure => _movementFailure;
  StockMovement? get lastMovementSuccess => _lastMovementSuccess;
  StockMovementIntent? get pendingMovementIntent => _pendingMovementIntent;
  bool get isMovementUncertain => _isMovementUncertain;

  List<StockMovement> get movements => _movements;
  bool get hasMoreMovements => _hasMoreMovements;
  bool get isLoadingMovements => _isLoadingMovements;
  InventoryFailure? get movementsFailure => _movementsFailure;

  ProductRecipe? get currentRecipe => _currentRecipe;
  bool get isLoadingRecipe => _isLoadingRecipe;
  bool get isSavingRecipe => _isSavingRecipe;
  InventoryFailure? get recipeFailure => _recipeFailure;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _handleSessionExpiry(InventoryFailure failure) {
    if (failure.kind == InventoryFailureKind.sessionExpired) {
      onSessionExpired?.call();
    }
  }

  // =========================================================================
  // Inventory List & Filtering
  // =========================================================================

  /// Loads initial list of items with the current filter.
  Future<void> start() async {
    await fetchItems();
  }

  /// Fetches inventory items using current filter, resetting to page 1.
  Future<void> fetchItems() async {
    if (_disposed) return;
    final currentGen = ++_generation;

    _isLoading = true;
    _listFailure = null;
    _notify();

    try {
      final page = await repository.getItems(_filter.copyWith(page: 1));
      if (_disposed || currentGen != _generation) return;

      _items = page.items;
      _hasMore = page.hasMore;
      _total = page.total;
      _filter = _filter.copyWith(page: 1);
      _isLoading = false;
      _notify();
    } on InventoryFailure catch (e) {
      if (_disposed || currentGen != _generation) return;
      _isLoading = false;
      _listFailure = e;
      _handleSessionExpiry(e);
      _notify();
    } catch (_) {
      if (_disposed || currentGen != _generation) return;
      _isLoading = false;
      _listFailure = const InventoryFailure(
        InventoryFailureKind.invalidResponse,
      );
      _notify();
    }
  }

  /// Pull-to-refresh action.
  Future<void> refresh() async {
    if (_disposed || _isLoading || _isRefreshing) return;
    final currentGen = ++_generation;

    _isRefreshing = true;
    _listFailure = null;
    _notify();

    try {
      final page = await repository.getItems(_filter.copyWith(page: 1));
      if (_disposed || currentGen != _generation) return;

      _items = page.items;
      _hasMore = page.hasMore;
      _total = page.total;
      _filter = _filter.copyWith(page: 1);
      _isRefreshing = false;

      // If an item is currently selected, refresh its details too
      if (_selectedItem != null) {
        unawaited(refreshSelectedItem());
      }

      _notify();
    } on InventoryFailure catch (e) {
      if (_disposed || currentGen != _generation) return;
      _isRefreshing = false;
      _listFailure = e;
      _handleSessionExpiry(e);
      _notify();
    } catch (_) {
      if (_disposed || currentGen != _generation) return;
      _isRefreshing = false;
      _listFailure = const InventoryFailure(
        InventoryFailureKind.invalidResponse,
      );
      _notify();
    }
  }

  /// Loads next page of items.
  Future<void> loadMore() async {
    if (_disposed ||
        _isLoading ||
        _isRefreshing ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }

    final currentGen = _generation;
    _isLoadingMore = true;
    _loadMoreFailure = null;
    _notify();

    final nextPage = _filter.page + 1;

    try {
      final page = await repository.getItems(_filter.copyWith(page: nextPage));
      if (_disposed || currentGen != _generation) return;

      _items = [..._items, ...page.items];
      _hasMore = page.hasMore;
      _total = page.total;
      _filter = _filter.copyWith(page: nextPage);
      _isLoadingMore = false;
      _notify();
    } on InventoryFailure catch (e) {
      if (_disposed || currentGen != _generation) return;
      _isLoadingMore = false;
      _loadMoreFailure = e;
      _handleSessionExpiry(e);
      _notify();
    } catch (_) {
      if (_disposed || currentGen != _generation) return;
      _isLoadingMore = false;
      _loadMoreFailure = const InventoryFailure(
        InventoryFailureKind.invalidResponse,
      );
      _notify();
    }
  }

  /// Sets search term with a 300ms debounce.
  void setSearch(String query) {
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (_filter.search == trimmed ||
        (_filter.search == null && trimmed.isEmpty)) {
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_disposed) return;
      _filter = _filter.copyWith(
        search: trimmed.isEmpty ? null : trimmed,
        clearSearch: trimmed.isEmpty,
        page: 1,
      );
      fetchItems();
    });
  }

  /// Immediately clears the search term.
  void clearSearch() {
    final hadPending = _searchDebounceTimer?.isActive ?? false;
    _searchDebounceTimer?.cancel();
    if (_filter.search == null && !hadPending) return;
    _filter = _filter.copyWith(clearSearch: true, page: 1);
    fetchItems();
  }

  /// Updates status filter ('active', 'inactive', 'all').
  void setStatus(String status) {
    if (_filter.status == status) return;
    _filter = _filter.copyWith(status: status, page: 1);
    fetchItems();
  }

  /// Updates low stock filter (null = all, true = low stock only, false = normal only).
  void setLowStock(bool? lowStock) {
    if (_filter.lowStock == lowStock) return;
    _filter = _filter.copyWith(
      lowStock: lowStock,
      clearLowStock: lowStock == null,
      page: 1,
    );
    fetchItems();
  }

  // =========================================================================
  // Item Selection & Detail
  // =========================================================================

  /// Selects an item for inspection and loads fresh details from server.
  void selectItem(InventoryItem item) {
    _selectedItem = item;
    _itemFailure = null;
    _movements = const [];
    _movementsPage = 1;
    _hasMoreMovements = false;
    _notify();

    refreshSelectedItem();
  }

  /// Clears the selected item.
  void clearSelectedItem() {
    _selectedItem = null;
    _itemFailure = null;
    _movements = const [];
    _notify();
  }

  /// Refreshes selected item details from the server.
  Future<void> refreshSelectedItem() async {
    final item = _selectedItem;
    if (item == null || _disposed) return;

    _isLoadingItem = true;
    _itemFailure = null;
    _notify();

    try {
      final updated = await repository.getItem(item.id);
      if (_disposed || _selectedItem?.id != item.id) return;

      _selectedItem = updated;
      _isLoadingItem = false;

      // Update in items list if present
      final index = _items.indexWhere((i) => i.id == updated.id);
      if (index >= 0) {
        final list = List<InventoryItem>.from(_items);
        list[index] = updated;
        _items = list;
      }

      _notify();
    } on InventoryFailure catch (e) {
      if (_disposed || _selectedItem?.id != item.id) return;
      _isLoadingItem = false;
      _itemFailure = e;
      _handleSessionExpiry(e);
      _notify();
    } catch (_) {
      if (_disposed || _selectedItem?.id != item.id) return;
      _isLoadingItem = false;
      _itemFailure = const InventoryFailure(
        InventoryFailureKind.invalidResponse,
      );
      _notify();
    }
  }

  // =========================================================================
  // Item Management (Create & Edit)
  // =========================================================================

  /// Creates a new inventory item.
  Future<InventoryItem?> createItem({
    required String sku,
    required String name,
    required BaseUnit baseUnit,
    ExactQuantity? reorderLevel,
    bool isActive = true,
  }) async {
    if (_disposed || _isCreating) return null;

    _isCreating = true;
    _createFailure = null;
    _notify();

    try {
      final newItem = await repository.createItem(
        sku: sku,
        name: name,
        baseUnit: baseUnit,
        reorderLevel: reorderLevel,
        isActive: isActive,
      );

      _isCreating = false;
      // Prepend to current items list if matches filter
      _items = [newItem, ..._items];
      _total++;
      _notify();
      return newItem;
    } on InventoryFailure catch (e) {
      _isCreating = false;
      _createFailure = e;
      _handleSessionExpiry(e);
      _notify();
      return null;
    } catch (_) {
      _isCreating = false;
      _createFailure = const InventoryFailure(
        InventoryFailureKind.invalidResponse,
      );
      _notify();
      return null;
    }
  }

  /// Updates allowed inventory item metadata.
  Future<InventoryItem?> updateItem(
    int id, {
    String? sku,
    String? name,
    ExactQuantity? reorderLevel,
    bool? isActive,
  }) async {
    if (_disposed || _isUpdating) return null;

    _isUpdating = true;
    _updateFailure = null;
    _notify();

    try {
      final updated = await repository.updateItem(
        id,
        sku: sku,
        name: name,
        reorderLevel: reorderLevel,
        isActive: isActive,
      );

      _isUpdating = false;
      if (_selectedItem?.id == id) {
        _selectedItem = updated;
      }

      final index = _items.indexWhere((i) => i.id == id);
      if (index >= 0) {
        final list = List<InventoryItem>.from(_items);
        list[index] = updated;
        _items = list;
      }

      _notify();
      return updated;
    } on InventoryFailure catch (e) {
      _isUpdating = false;
      _updateFailure = e;
      _handleSessionExpiry(e);
      _notify();
      return null;
    } catch (_) {
      _isUpdating = false;
      _updateFailure = const InventoryFailure(
        InventoryFailureKind.invalidResponse,
      );
      _notify();
      return null;
    }
  }

  // =========================================================================
  // Stock Movements & Idempotency
  // =========================================================================

  /// Creates a manual stock movement with stable idempotency protection.
  Future<StockMovement?> createMovement({
    required int inventoryItemId,
    required StockMovementReason reason,
    required ExactQuantity quantityDelta,
    String? note,
  }) async {
    if (_disposed || _isSubmittingMovement) return null;

    final idempotencyKey = _keyGenerator();
    final intent = StockMovementIntent(
      inventoryItemId: inventoryItemId,
      reason: reason,
      quantityDelta: quantityDelta,
      note: note,
      idempotencyKey: idempotencyKey,
    );

    return _submitMovement(intent);
  }

  /// Re-submits an uncertain movement using the exact SAME intent and idempotency key.
  Future<StockMovement?> retryUncertainMovement() async {
    final intent = _pendingMovementIntent;
    if (intent == null || _disposed || _isSubmittingMovement) return null;

    return _submitMovement(intent);
  }

  /// Clears the uncertain state if the operator verifies server balance externally.
  void clearUncertainMovement() {
    _pendingMovementIntent = null;
    _isMovementUncertain = false;
    _movementFailure = null;
    _notify();
  }

  Future<StockMovement?> _submitMovement(StockMovementIntent intent) async {
    _isSubmittingMovement = true;
    _movementFailure = null;
    _pendingMovementIntent = intent;
    _notify();

    try {
      final movement = await repository.createMovement(intent);
      if (_disposed) return movement;

      _isSubmittingMovement = false;
      _isMovementUncertain = false;
      _pendingMovementIntent = null;
      _lastMovementSuccess = movement;

      // Refresh authoritative item balance
      if (_selectedItem?.id == intent.inventoryItemId) {
        await refreshSelectedItem();
        // Prepend movement to ledger if loaded
        if (_movements.isNotEmpty) {
          _movements = [movement, ..._movements];
        }
      }

      _notify();
      return movement;
    } on InventoryFailure catch (e) {
      if (_disposed) return null;
      _isSubmittingMovement = false;
      _movementFailure = e;

      // If network error, mark as uncertain so operator can explicitly retry with SAME key
      if (e.kind == InventoryFailureKind.network ||
          e.kind == InventoryFailureKind.server) {
        _isMovementUncertain = true;
      } else {
        // Validation / Conflict / Forbidden / 401: clear pending intent
        _isMovementUncertain = false;
        _pendingMovementIntent = null;
      }

      _handleSessionExpiry(e);
      _notify();
      return null;
    } catch (_) {
      if (_disposed) return null;
      _isSubmittingMovement = false;
      _isMovementUncertain = true;
      _movementFailure = const InventoryFailure(InventoryFailureKind.network);
      _notify();
      return null;
    }
  }

  // =========================================================================
  // Movement Ledger History
  // =========================================================================

  /// Loads the initial ledger page for the selected item.
  Future<void> loadMovements() async {
    final item = _selectedItem;
    if (item == null || _disposed || _isLoadingMovements) return;

    _isLoadingMovements = true;
    _movementsFailure = null;
    _movementsPage = 1;
    _notify();

    try {
      final page = await repository.getMovements(item.id, page: 1, perPage: 25);
      if (_disposed || _selectedItem?.id != item.id) return;

      _movements = page.items;
      _hasMoreMovements = page.hasMore;
      _movementsPage = 1;
      _isLoadingMovements = false;
      _notify();
    } on InventoryFailure catch (e) {
      if (_disposed || _selectedItem?.id != item.id) return;
      _isLoadingMovements = false;
      _movementsFailure = e;
      _handleSessionExpiry(e);
      _notify();
    } catch (_) {
      if (_disposed || _selectedItem?.id != item.id) return;
      _isLoadingMovements = false;
      _movementsFailure = const InventoryFailure(
        InventoryFailureKind.invalidResponse,
      );
      _notify();
    }
  }

  /// Loads the next page of movements for the selected item.
  Future<void> loadMoreMovements() async {
    final item = _selectedItem;
    if (item == null ||
        _disposed ||
        _isLoadingMovements ||
        !_hasMoreMovements) {
      return;
    }

    final nextPage = _movementsPage + 1;
    _isLoadingMovements = true;
    _notify();

    try {
      final page = await repository.getMovements(
        item.id,
        page: nextPage,
        perPage: 25,
      );
      if (_disposed || _selectedItem?.id != item.id) return;

      _movements = [..._movements, ...page.items];
      _hasMoreMovements = page.hasMore;
      _movementsPage = nextPage;
      _isLoadingMovements = false;
      _notify();
    } on InventoryFailure catch (e) {
      if (_disposed || _selectedItem?.id != item.id) return;
      _isLoadingMovements = false;
      _movementsFailure = e;
      _handleSessionExpiry(e);
      _notify();
    } catch (_) {
      if (_disposed || _selectedItem?.id != item.id) return;
      _isLoadingMovements = false;
      _notify();
    }
  }

  // =========================================================================
  // Product Recipe Management
  // =========================================================================

  /// Loads recipe for a specified product.
  Future<ProductRecipe?> loadRecipe(int productId) async {
    if (_disposed) return null;

    _isLoadingRecipe = true;
    _recipeFailure = null;
    _currentRecipe = null;
    _notify();

    try {
      final recipe = await repository.getRecipe(productId);
      if (_disposed) return null;

      _currentRecipe = recipe;
      _isLoadingRecipe = false;
      _notify();
      return recipe;
    } on InventoryFailure catch (e) {
      if (_disposed) return null;
      _isLoadingRecipe = false;
      _recipeFailure = e;
      _handleSessionExpiry(e);
      _notify();
      return null;
    } catch (_) {
      if (_disposed) return null;
      _isLoadingRecipe = false;
      _recipeFailure = const InventoryFailure(
        InventoryFailureKind.invalidResponse,
      );
      _notify();
      return null;
    }
  }

  /// Replaces the product recipe atomically.
  Future<ProductRecipe?> saveRecipe(
    int productId,
    List<RecipeIngredientPayload> ingredients,
  ) async {
    if (_disposed || _isSavingRecipe) return null;

    _isSavingRecipe = true;
    _recipeFailure = null;
    _notify();

    try {
      final updated = await repository.replaceRecipe(productId, ingredients);
      if (_disposed) return null;

      _currentRecipe = updated;
      _isSavingRecipe = false;
      _notify();
      return updated;
    } on InventoryFailure catch (e) {
      if (_disposed) return null;
      _isSavingRecipe = false;
      _recipeFailure = e;
      _handleSessionExpiry(e);
      _notify();
      return null;
    } catch (_) {
      if (_disposed) return null;
      _isSavingRecipe = false;
      _recipeFailure = const InventoryFailure(
        InventoryFailureKind.invalidResponse,
      );
      _notify();
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}
