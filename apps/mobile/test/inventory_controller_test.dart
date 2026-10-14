import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:coffee_management_mobile/features/inventory/domain/exact_quantity.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_filter.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_item.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_repository.dart';
import 'package:coffee_management_mobile/features/inventory/domain/product_recipe.dart';
import 'package:coffee_management_mobile/features/inventory/domain/stock_movement.dart';
import 'package:coffee_management_mobile/features/inventory/presentation/inventory_controller.dart';

ExactQuantity qty(int units) =>
    ExactQuantity.fromSubunits(units * ExactQuantity.scale);

class FakeInventoryRepository implements InventoryRepository {
  Future<InventoryPage> Function(InventoryFilter filter)? onGetItems;
  Future<InventoryItem> Function(int id)? onGetItem;
  Future<InventoryItem> Function({
    required String sku,
    required String name,
    required BaseUnit baseUnit,
    ExactQuantity? reorderLevel,
    bool isActive,
  })?
  onCreateItem;
  Future<InventoryItem> Function(
    int id, {
    String? sku,
    String? name,
    ExactQuantity? reorderLevel,
    bool? isActive,
  })?
  onUpdateItem;
  Future<StockMovement> Function(StockMovementIntent intent)? onCreateMovement;
  Future<StockMovementPage> Function(int itemId, {int page, int perPage})?
  onGetMovements;
  Future<ProductRecipe> Function(int productId)? onGetRecipe;
  Future<ProductRecipe> Function(
    int productId,
    List<RecipeIngredientPayload> ingredients,
  )?
  onReplaceRecipe;

  final getItemsRequests = <InventoryFilter>[];
  final getItemRequests = <int>[];
  final createMovementRequests = <StockMovementIntent>[];
  final getMovementsRequests = <({int itemId, int page, int perPage})>[];

  @override
  Future<InventoryPage> getItems(InventoryFilter filter) async {
    getItemsRequests.add(filter);
    if (onGetItems != null) {
      return onGetItems!(filter);
    }
    return InventoryPage(
      items: [sampleItem(id: 1, name: 'Espresso Beans')],
      currentPage: filter.page,
      lastPage: 1,
      perPage: filter.perPage,
      total: 1,
    );
  }

  @override
  Future<InventoryItem> getItem(int id) async {
    getItemRequests.add(id);
    if (onGetItem != null) {
      return onGetItem!(id);
    }
    return sampleItem(id: id);
  }

  @override
  Future<InventoryItem> createItem({
    required String sku,
    required String name,
    required BaseUnit baseUnit,
    ExactQuantity? reorderLevel,
    bool isActive = true,
  }) async {
    if (onCreateItem != null) {
      return onCreateItem!(
        sku: sku,
        name: name,
        baseUnit: baseUnit,
        reorderLevel: reorderLevel,
        isActive: isActive,
      );
    }
    return sampleItem(
      id: 99,
      sku: sku,
      name: name,
      baseUnit: baseUnit,
      reorderLevel: reorderLevel ?? ExactQuantity.zero,
      isActive: isActive,
    );
  }

  @override
  Future<InventoryItem> updateItem(
    int id, {
    String? sku,
    String? name,
    ExactQuantity? reorderLevel,
    bool? isActive,
  }) async {
    if (onUpdateItem != null) {
      return onUpdateItem!(
        id,
        sku: sku,
        name: name,
        reorderLevel: reorderLevel,
        isActive: isActive,
      );
    }
    return sampleItem(
      id: id,
      sku: sku ?? 'SKU-$id',
      name: name ?? 'Updated Item $id',
      reorderLevel: reorderLevel ?? ExactQuantity.zero,
      isActive: isActive ?? true,
    );
  }

  @override
  Future<StockMovement> createMovement(StockMovementIntent intent) async {
    createMovementRequests.add(intent);
    if (onCreateMovement != null) {
      return onCreateMovement!(intent);
    }
    return sampleMovement(
      id: 10,
      inventoryItemId: intent.inventoryItemId,
      quantityDelta: intent.quantityDelta,
      reason: intent.reason,
      note: intent.note,
    );
  }

  @override
  Future<StockMovementPage> getMovements(
    int itemId, {
    int page = 1,
    int perPage = 25,
  }) async {
    getMovementsRequests.add((itemId: itemId, page: page, perPage: perPage));
    if (onGetMovements != null) {
      return onGetMovements!(itemId, page: page, perPage: perPage);
    }
    return StockMovementPage(
      items: [sampleMovement(id: 1, inventoryItemId: itemId)],
      currentPage: page,
      lastPage: 1,
      perPage: perPage,
      total: 1,
    );
  }

  @override
  Future<ProductRecipe> getRecipe(int productId) async {
    if (onGetRecipe != null) {
      return onGetRecipe!(productId);
    }
    return ProductRecipe(
      productId: productId,
      ingredients: [
        RecipeIngredient(
          inventoryItemId: 1,
          name: 'Espresso Beans',
          sku: 'BEAN-01',
          baseUnit: BaseUnit.g,
          isActive: true,
          quantity: qty(18),
        ),
      ],
    );
  }

  @override
  Future<ProductRecipe> replaceRecipe(
    int productId,
    List<RecipeIngredientPayload> ingredients,
  ) async {
    if (onReplaceRecipe != null) {
      return onReplaceRecipe!(productId, ingredients);
    }
    return ProductRecipe(
      productId: productId,
      ingredients: ingredients
          .map<RecipeIngredient>(
            (p) => RecipeIngredient(
              inventoryItemId: p.inventoryItemId,
              name: 'Item ${p.inventoryItemId}',
              sku: 'SKU-${p.inventoryItemId}',
              baseUnit: BaseUnit.g,
              isActive: true,
              quantity: p.quantity,
            ),
          )
          .toList(),
    );
  }
}

InventoryItem sampleItem({
  int id = 1,
  String sku = 'BEAN-01',
  String name = 'Espresso Beans',
  BaseUnit baseUnit = BaseUnit.g,
  ExactQuantity? onHand,
  ExactQuantity? reserved,
  ExactQuantity? available,
  ExactQuantity? reorderLevel,
  bool isActive = true,
  bool lowStock = false,
}) {
  return InventoryItem(
    id: id,
    sku: sku,
    name: name,
    baseUnit: baseUnit,
    onHand: onHand ?? qty(1000),
    reserved: reserved ?? ExactQuantity.zero,
    available: available ?? qty(1000),
    reorderLevel: reorderLevel ?? qty(200),
    isActive: isActive,
    lowStock: lowStock,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

StockMovement sampleMovement({
  int id = 1,
  int inventoryItemId = 1,
  ExactQuantity? quantityDelta,
  StockMovementReason reason = StockMovementReason.receipt,
  String? note,
}) {
  return StockMovement(
    id: id,
    inventoryItemId: inventoryItemId,
    quantityDelta: quantityDelta ?? qty(500),
    reason: reason,
    note: note,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('InventoryController - List & Filtering', () {
    late FakeInventoryRepository repository;
    late InventoryController controller;

    setUp(() {
      repository = FakeInventoryRepository();
      controller = InventoryController(
        repository: repository,
        keyGenerator: () => 'fixed-key-12345',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('start() loads page 1 and populates items and total', () async {
      final item1 = sampleItem(id: 1, name: 'Beans');
      final item2 = sampleItem(id: 2, name: 'Milk');
      repository.onGetItems = (filter) async {
        return InventoryPage(
          items: [item1, item2],
          currentPage: 1,
          lastPage: 2,
          perPage: 25,
          total: 2,
        );
      };

      expect(controller.isLoading, isFalse);
      expect(controller.items, isEmpty);

      await controller.start();

      expect(controller.isLoading, isFalse);
      expect(controller.items.length, 2);
      expect(controller.items[0].name, 'Beans');
      expect(controller.total, 2);
      expect(controller.hasMore, isTrue);
      expect(controller.listFailure, isNull);
    });

    test('start() captures failure on network error', () async {
      repository.onGetItems = (filter) async {
        throw const InventoryFailure(
          InventoryFailureKind.network,
          detail: 'Connection timed out',
        );
      };

      await controller.start();

      expect(controller.isLoading, isFalse);
      expect(controller.items, isEmpty);
      expect(controller.listFailure?.kind, InventoryFailureKind.network);
    });

    test('start() notifies onSessionExpired on 401 unauthenticated', () async {
      var sessionExpiredCalled = false;
      final authController = InventoryController(
        repository: repository,
        onSessionExpired: () => sessionExpiredCalled = true,
      );

      repository.onGetItems = (filter) async {
        throw const InventoryFailure(InventoryFailureKind.sessionExpired);
      };

      await authController.start();

      expect(sessionExpiredCalled, isTrue);
      expect(
        authController.listFailure?.kind,
        InventoryFailureKind.sessionExpired,
      );
      authController.dispose();
    });

    test('loadMore() appends subsequent pages to existing items', () async {
      final page1 = [sampleItem(id: 1, name: 'Item 1')];
      final page2 = [sampleItem(id: 2, name: 'Item 2')];

      repository.onGetItems = (filter) async {
        if (filter.page == 1) {
          return InventoryPage(
            items: page1,
            currentPage: 1,
            lastPage: 2,
            perPage: 1,
            total: 2,
          );
        } else {
          return InventoryPage(
            items: page2,
            currentPage: 2,
            lastPage: 2,
            perPage: 1,
            total: 2,
          );
        }
      };

      await controller.start();
      expect(controller.items.length, 1);
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.items.length, 2);
      expect(controller.items[0].name, 'Item 1');
      expect(controller.items[1].name, 'Item 2');
      expect(controller.hasMore, isFalse);
    });

    test('refresh() updates items and reloads selected item details', () async {
      final initialItem = sampleItem(id: 1, name: 'Old Beans');
      final refreshedItem = sampleItem(
        id: 1,
        name: 'Fresh Beans',
        onHand: qty(2000),
      );

      repository.onGetItems = (filter) async => InventoryPage(
        items: [refreshedItem],
        currentPage: 1,
        lastPage: 1,
        perPage: 25,
        total: 1,
      );
      repository.onGetItem = (id) async => refreshedItem;

      controller.selectItem(initialItem);
      await controller.refresh();

      expect(controller.items.first.name, 'Fresh Beans');
      expect(controller.selectedItem?.name, 'Fresh Beans');
      expect(controller.selectedItem?.onHand, qty(2000));
    });

    test(
      'setStatus and setLowStock trigger immediate filter updates and refetch',
      () async {
        await controller.start();
        expect(repository.getItemsRequests.length, 1);

        controller.setStatus('inactive');
        await Future<void>.delayed(Duration.zero);
        expect(controller.filter.status, 'inactive');
        expect(repository.getItemsRequests.last.status, 'inactive');

        controller.setLowStock(true);
        await Future<void>.delayed(Duration.zero);
        expect(controller.filter.lowStock, isTrue);
        expect(repository.getItemsRequests.last.lowStock, isTrue);

        controller.setLowStock(null);
        await Future<void>.delayed(Duration.zero);
        expect(controller.filter.lowStock, isNull);
      },
    );

    test('setSearch debounces 300ms before triggering fetch', () async {
      await controller.start();
      final initialRequestCount = repository.getItemsRequests.length;

      controller.setSearch('arabica');
      // Should not have fetched immediately
      expect(repository.getItemsRequests.length, initialRequestCount);

      // Fast forward past debounce duration
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(repository.getItemsRequests.length, initialRequestCount + 1);
      expect(repository.getItemsRequests.last.search, 'arabica');
    });

    test(
      'clearSearch immediately clears query and triggers fetch without waiting for timer',
      () async {
        controller.setSearch('temp');
        controller.clearSearch();

        await Future<void>.delayed(Duration.zero);
        expect(controller.filter.search, isNull);
        expect(repository.getItemsRequests.last.search, isNull);
      },
    );

    test(
      'generation protection ignores slow response from superseded fetch',
      () async {
        final completerA = Completer<InventoryPage>();
        final completerB = Completer<InventoryPage>();

        var callIndex = 0;
        repository.onGetItems = (filter) {
          callIndex++;
          if (callIndex == 1) return completerA.future;
          return completerB.future;
        };

        // Start fetch A
        final futureA = controller.fetchItems();
        // Start fetch B (new generation)
        final futureB = controller.fetchItems();

        // Resolve B first with fresh data
        completerB.complete(
          InventoryPage(
            items: [sampleItem(id: 2, name: 'Fresh Data B')],
            currentPage: 1,
            lastPage: 1,
            perPage: 25,
            total: 1,
          ),
        );
        await futureB;
        expect(controller.items.single.name, 'Fresh Data B');

        // Now resolve A late with stale data
        completerA.complete(
          InventoryPage(
            items: [sampleItem(id: 1, name: 'Stale Data A')],
            currentPage: 1,
            lastPage: 1,
            perPage: 25,
            total: 1,
          ),
        );
        await futureA;

        // Controller must keep B's data and discard A
        expect(controller.items.single.name, 'Fresh Data B');
      },
    );
  });

  group('InventoryController - Item CRUD Operations', () {
    late FakeInventoryRepository repository;
    late InventoryController controller;

    setUp(() {
      repository = FakeInventoryRepository();
      controller = InventoryController(
        repository: repository,
        keyGenerator: () => 'fixed-key-12345',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test(
      'createItem() prepends new item to items list and increments total',
      () async {
        await controller.start();
        expect(controller.total, 1);

        final created = await controller.createItem(
          sku: 'MILK-WHOLE',
          name: 'Whole Milk',
          baseUnit: BaseUnit.ml,
          reorderLevel: qty(5000),
        );

        expect(created, isNotNull);
        expect(created!.sku, 'MILK-WHOLE');
        expect(controller.items.first.sku, 'MILK-WHOLE');
        expect(controller.total, 2);
        expect(controller.createFailure, isNull);
      },
    );

    test('updateItem() modifies item in items list and selectedItem', () async {
      final initialItem = sampleItem(id: 42, name: 'Old Syrup');
      repository.onGetItems = (filter) async => InventoryPage(
        items: [initialItem],
        currentPage: 1,
        lastPage: 1,
        perPage: 25,
        total: 1,
      );

      await controller.start();
      controller.selectItem(initialItem);

      final updated = await controller.updateItem(
        42,
        name: 'Vanilla Syrup',
        reorderLevel: qty(10),
      );

      expect(updated, isNotNull);
      expect(controller.items.single.name, 'Vanilla Syrup');
      expect(controller.selectedItem?.name, 'Vanilla Syrup');
      expect(controller.updateFailure, isNull);
    });
  });

  group('InventoryController - Stock Movements & Idempotency', () {
    late FakeInventoryRepository repository;
    var currentKey = 'key-001';
    late InventoryController controller;

    setUp(() {
      repository = FakeInventoryRepository();
      currentKey = 'key-00001';
      controller = InventoryController(
        repository: repository,
        keyGenerator: () => currentKey,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test(
      'createMovement() submits with generated idempotency key and updates balance',
      () async {
        final item = sampleItem(id: 1, onHand: qty(100));
        controller.selectItem(item);

        final result = await controller.createMovement(
          inventoryItemId: 1,
          reason: StockMovementReason.receipt,
          quantityDelta: qty(50),
          note: 'Weekly delivery',
        );

        expect(result, isNotNull);
        expect(repository.createMovementRequests.length, 1);
        final request = repository.createMovementRequests.single;
        expect(request.idempotencyKey, 'key-00001');
        expect(request.quantityDelta, qty(50));
        expect(request.reason, StockMovementReason.receipt);
        expect(controller.isMovementUncertain, isFalse);
        expect(controller.pendingMovementIntent, isNull);
      },
    );

    test(
      'createMovement() on network timeout marks uncertain and preserves identical key for retry',
      () async {
        final item = sampleItem(id: 1);
        controller.selectItem(item);

        // Simulate network timeout on first attempt
        repository.onCreateMovement = (intent) async {
          throw const InventoryFailure(
            InventoryFailureKind.network,
            detail: 'Connection timed out while sending movement',
          );
        };

        final result = await controller.createMovement(
          inventoryItemId: 1,
          reason: StockMovementReason.waste,
          quantityDelta: qty(-5),
          note: 'Spilled beans',
        );

        expect(result, isNull);
        expect(controller.isMovementUncertain, isTrue);
        expect(controller.pendingMovementIntent, isNotNull);
        expect(controller.pendingMovementIntent!.idempotencyKey, 'key-00001');

        // Now change key generator to ensure retry DOES NOT call generator or change the key!
        currentKey = 'new-unexpected-key-999';

        // Simulate recovery on retry
        repository.onCreateMovement = (intent) async {
          return sampleMovement(
            id: 55,
            inventoryItemId: intent.inventoryItemId,
            quantityDelta: intent.quantityDelta,
            reason: intent.reason,
            note: intent.note,
          );
        };

        final retryResult = await controller.retryUncertainMovement();

        expect(retryResult, isNotNull);
        expect(controller.isMovementUncertain, isFalse);
        expect(controller.pendingMovementIntent, isNull);

        // Verify that BOTH attempts used the exact same key: 'key-00001'
        expect(repository.createMovementRequests.length, 2);
        expect(
          repository.createMovementRequests[0].idempotencyKey,
          'key-00001',
        );
        expect(
          repository.createMovementRequests[1].idempotencyKey,
          'key-00001',
        );
      },
    );

    test('clearUncertainMovement() explicitly discards held intent', () async {
      repository.onCreateMovement = (intent) async {
        throw const InventoryFailure(InventoryFailureKind.network);
      };

      await controller.createMovement(
        inventoryItemId: 1,
        reason: StockMovementReason.receipt,
        quantityDelta: qty(10),
      );

      expect(controller.isMovementUncertain, isTrue);
      expect(controller.pendingMovementIntent, isNotNull);

      controller.clearUncertainMovement();

      expect(controller.isMovementUncertain, isFalse);
      expect(controller.pendingMovementIntent, isNull);
    });

    test(
      'non-network failure (e.g. validation or 409 conflict) does not enter uncertain retry state',
      () async {
        repository.onCreateMovement = (intent) async {
          throw const InventoryFailure(
            InventoryFailureKind.conflict,
            detail: 'Concurrent adjustment conflict detected',
          );
        };

        final result = await controller.createMovement(
          inventoryItemId: 1,
          reason: StockMovementReason.receipt,
          quantityDelta: qty(10),
        );

        expect(result, isNull);
        expect(controller.movementFailure?.kind, InventoryFailureKind.conflict);
        expect(controller.isMovementUncertain, isFalse);
        expect(controller.pendingMovementIntent, isNull);
      },
    );
  });

  group('InventoryController - Recipe Management', () {
    late FakeInventoryRepository repository;
    late InventoryController controller;

    setUp(() {
      repository = FakeInventoryRepository();
      controller = InventoryController(repository: repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('loadRecipe() loads product recipe', () async {
      final recipe = await controller.loadRecipe(10);

      expect(recipe, isNotNull);
      expect(recipe!.productId, 10);
      expect(recipe.ingredients.length, 1);
      expect(controller.currentRecipe, isNotNull);
      expect(controller.recipeFailure, isNull);
    });

    test('saveRecipe() replaces recipe atomically', () async {
      final payload = [
        RecipeIngredientPayload(inventoryItemId: 1, quantity: qty(20)),
        RecipeIngredientPayload(inventoryItemId: 2, quantity: qty(150)),
      ];

      final updated = await controller.saveRecipe(10, payload);

      expect(updated, isNotNull);
      expect(updated!.ingredients.length, 2);
      expect(controller.currentRecipe?.ingredients.length, 2);
      expect(controller.recipeFailure, isNull);
    });
  });
}
