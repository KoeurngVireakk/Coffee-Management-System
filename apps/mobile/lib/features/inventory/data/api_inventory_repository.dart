import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/exact_quantity.dart';
import '../domain/inventory_filter.dart';
import '../domain/inventory_item.dart';
import '../domain/inventory_repository.dart';
import '../domain/product_recipe.dart';
import '../domain/stock_movement.dart';
import 'inventory_dto.dart';

/// Production implementation of [InventoryRepository] backed by the Laravel REST API.
class ApiInventoryRepository implements InventoryRepository {
  ApiInventoryRepository({required this.client, required this.token});

  final ApiClient client;
  final String token;

  Never _mapError(Object error, [StackTrace? stackTrace]) {
    if (error is UnauthorizedException) {
      throw const InventoryFailure(InventoryFailureKind.sessionExpired);
    }
    if (error is ForbiddenException) {
      throw const InventoryFailure(InventoryFailureKind.forbidden);
    }
    if (error is NotFoundException) {
      throw const InventoryFailure(InventoryFailureKind.notFound);
    }
    if (error is ConflictException) {
      throw InventoryFailure(
        InventoryFailureKind.conflict,
        detail: error.message,
      );
    }
    if (error is ValidationException) {
      throw InventoryFailure(
        InventoryFailureKind.validation,
        detail: error.message,
        errors: error.errors,
      );
    }
    if (error is RateLimitedException) {
      throw InventoryFailure(
        InventoryFailureKind.rateLimited,
        retryAfterSeconds: error.retryAfterSeconds,
      );
    }
    if (error is NetworkException) {
      throw InventoryFailure(
        InventoryFailureKind.network,
        detail: error.message,
      );
    }
    if (error is ServerException) {
      throw InventoryFailure(
        InventoryFailureKind.server,
        detail: error.message,
      );
    }
    if (error is FormatException || error is InvalidResponseException) {
      throw const InventoryFailure(InventoryFailureKind.invalidResponse);
    }
    throw const InventoryFailure(InventoryFailureKind.invalidResponse);
  }

  @override
  Future<InventoryPage> getItems(InventoryFilter filter) async {
    try {
      final response = await client.get(
        'inventory/items',
        queryParameters: filter.toQueryParameters(),
        token: token,
      );
      return InventoryDto.itemPage(
        response,
        requestedPage: filter.page,
        requestedPerPage: filter.perPage,
      );
    } catch (e, st) {
      _mapError(e, st);
    }
  }

  @override
  Future<InventoryItem> getItem(int id) async {
    try {
      final response = await client.get('inventory/items/$id', token: token);
      return InventoryDto.item(response);
    } catch (e, st) {
      _mapError(e, st);
    }
  }

  @override
  Future<InventoryItem> createItem({
    required String sku,
    required String name,
    required BaseUnit baseUnit,
    ExactQuantity? reorderLevel,
    bool isActive = true,
  }) async {
    try {
      final payload = <String, dynamic>{
        'sku': sku.trim().toUpperCase(),
        'name': name.trim(),
        'base_unit': baseUnit.value,
        'is_active': isActive,
      };
      if (reorderLevel != null) {
        payload['reorder_level'] = reorderLevel.toCanonicalString();
      }

      final response = await client.post(
        'inventory/items',
        body: payload,
        token: token,
      );
      return InventoryDto.item(response);
    } catch (e, st) {
      _mapError(e, st);
    }
  }

  @override
  Future<InventoryItem> updateItem(
    int id, {
    String? sku,
    String? name,
    ExactQuantity? reorderLevel,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (sku != null) payload['sku'] = sku.trim().toUpperCase();
      if (name != null) payload['name'] = name.trim();
      if (reorderLevel != null) {
        payload['reorder_level'] = reorderLevel.toCanonicalString();
      }
      if (isActive != null) payload['is_active'] = isActive;

      final response = await client.patch(
        'inventory/items/$id',
        body: payload,
        token: token,
      );
      return InventoryDto.item(response);
    } catch (e, st) {
      _mapError(e, st);
    }
  }

  @override
  Future<StockMovementPage> getMovements(
    int itemId, {
    int page = 1,
    int perPage = 25,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (page > 1) queryParams['page'] = page.toString();
      if (perPage != 25) queryParams['per_page'] = perPage.toString();

      final response = await client.get(
        'inventory/items/$itemId/movements',
        queryParameters: queryParams.isEmpty ? null : queryParams,
        token: token,
      );
      return InventoryDto.movementPage(
        response,
        requestedPage: page,
        requestedPerPage: perPage,
      );
    } catch (e, st) {
      _mapError(e, st);
    }
  }

  @override
  Future<StockMovement> createMovement(StockMovementIntent intent) async {
    try {
      final headers = {'Idempotency-Key': intent.idempotencyKey};
      final response = await client.post(
        'inventory/items/${intent.inventoryItemId}/movements',
        headers: headers,
        body: intent.toJson(),
        token: token,
      );
      return InventoryDto.movement(response);
    } catch (e, st) {
      _mapError(e, st);
    }
  }

  @override
  Future<ProductRecipe> getRecipe(int productId) async {
    try {
      final response = await client.get(
        'products/$productId/recipe',
        token: token,
      );
      return InventoryDto.recipe(response);
    } catch (e, st) {
      _mapError(e, st);
    }
  }

  @override
  Future<ProductRecipe> replaceRecipe(
    int productId,
    List<RecipeIngredientPayload> ingredients,
  ) async {
    try {
      final payload = {
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      };
      final response = await client.put(
        'products/$productId/recipe',
        body: payload,
        token: token,
      );
      return InventoryDto.recipe(response);
    } catch (e, st) {
      _mapError(e, st);
    }
  }
}
