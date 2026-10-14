import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coffee_management_mobile/core/network/api_client.dart';
import 'package:coffee_management_mobile/features/inventory/data/api_inventory_repository.dart';
import 'package:coffee_management_mobile/features/inventory/data/inventory_dto.dart';
import 'package:coffee_management_mobile/features/inventory/domain/exact_quantity.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_filter.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_item.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_repository.dart';
import 'package:coffee_management_mobile/features/inventory/domain/product_recipe.dart';
import 'package:coffee_management_mobile/features/inventory/domain/stock_movement.dart';

void main() {
  Map<String, dynamic> sampleItemJson({
    int id = 1,
    String sku = 'BEANS',
    String name = 'Coffee Beans',
    String baseUnit = 'g',
    String onHand = '5000.0000',
    String reserved = '250.0000',
    String available = '4750.0000',
    String reorderLevel = '1000.0000',
    bool isActive = true,
    bool lowStock = false,
  }) => {
    'id': id,
    'sku': sku,
    'name': name,
    'base_unit': baseUnit,
    'on_hand': onHand,
    'reserved': reserved,
    'available': available,
    'reorder_level': reorderLevel,
    'is_active': isActive,
    'low_stock': lowStock,
    'created_at': '2026-10-14T08:00:00+00:00',
    'updated_at': '2026-10-14T08:00:00+00:00',
  };

  Map<String, dynamic> samplePageJson(
    List<Map<String, dynamic>> items, {
    int currentPage = 1,
    int lastPage = 1,
    int perPage = 25,
    int total = 1,
  }) => {
    'data': items,
    'links': {
      'first': 'https://api.test/api/v1/inventory/items?page=1',
      'last': 'https://api.test/api/v1/inventory/items?page=$lastPage',
      'prev': null,
      'next': null,
    },
    'meta': {
      'current_page': currentPage,
      'from': items.isEmpty ? null : 1,
      'last_page': lastPage,
      'path': 'https://api.test/api/v1/inventory/items',
      'per_page': perPage,
      'to': items.isEmpty ? null : items.length,
      'total': total,
    },
  };

  group('InventoryDto Decoding', () {
    test('strictly decodes single InventoryItem', () {
      final json = sampleItemJson();
      final item = InventoryDto.item({'data': json});

      expect(item.id, equals(1));
      expect(item.sku, equals('BEANS'));
      expect(item.name, equals('Coffee Beans'));
      expect(item.baseUnit, equals(BaseUnit.g));
      expect(item.onHand.toCanonicalString(), equals('5000.0000'));
      expect(item.reserved.toCanonicalString(), equals('250.0000'));
      expect(item.available.toCanonicalString(), equals('4750.0000'));
      expect(item.reorderLevel.toCanonicalString(), equals('1000.0000'));
      expect(item.isActive, isTrue);
      expect(item.lowStock, isFalse);
    });

    test('rejects item with invalid base unit', () {
      final json = sampleItemJson(baseUnit: 'liters');
      expect(() => InventoryDto.item(json), throwsFormatException);
    });

    test('rejects item with non-string quantity', () {
      final json = sampleItemJson();
      json['on_hand'] = 5000;
      expect(() => InventoryDto.item(json), throwsFormatException);
    });

    test(
      'strictly decodes paginated InventoryPage and catches duplicate IDs',
      () {
        final pageJson = samplePageJson([
          sampleItemJson(id: 1, sku: 'BEANS_1'),
          sampleItemJson(id: 1, sku: 'BEANS_2'),
        ], total: 2);

        expect(
          () => InventoryDto.itemPage(
            pageJson,
            requestedPage: 1,
            requestedPerPage: 25,
          ),
          throwsFormatException,
        );
      },
    );

    test('strictly decodes StockMovement', () {
      final json = {
        'id': 101,
        'inventory_item_id': 1,
        'order_id': null,
        'actor_id': 4,
        'quantity_delta': '5000.0000',
        'reason': 'receipt',
        'note': 'Weekly bean shipment',
        'created_at': '2026-10-14T09:00:00+00:00',
      };
      final movement = InventoryDto.movement({'data': json});

      expect(movement.id, equals(101));
      expect(movement.inventoryItemId, equals(1));
      expect(movement.quantityDelta.toCanonicalString(), equals('5000.0000'));
      expect(movement.reason, equals(StockMovementReason.receipt));
      expect(movement.note, equals('Weekly bean shipment'));
    });

    test('strictly decodes ProductRecipe', () {
      final json = {
        'data': {
          'product_id': 5,
          'ingredients': [
            {
              'inventory_item_id': 1,
              'sku': 'BEANS',
              'name': 'Coffee Beans',
              'base_unit': 'g',
              'is_active': true,
              'quantity': '18.0000',
            },
            {
              'inventory_item_id': 2,
              'sku': 'MILK',
              'name': 'Fresh Milk',
              'base_unit': 'ml',
              'is_active': true,
              'quantity': '180.0000',
            },
          ],
        },
      };
      final recipe = InventoryDto.recipe(json);

      expect(recipe.productId, equals(5));
      expect(recipe.ingredients.length, equals(2));
      expect(
        recipe.ingredients[0].quantity.toCanonicalString(),
        equals('18.0000'),
      );
      expect(recipe.ingredients[1].baseUnit, equals(BaseUnit.ml));
    });
  });

  group('ApiInventoryRepository Integration', () {
    test(
      'getItems passes allowlisted query parameters and authorization header',
      () async {
        late http.Request captured;

        final mock = MockClient((request) async {
          captured = request;
          final page = samplePageJson([sampleItemJson()]);
          return http.Response(jsonEncode(page), 200);
        });

        final repo = ApiInventoryRepository(
          client: ApiClient(client: mock, baseUrl: 'https://api.test/api/v1'),
          token: 'secret-token-xyz',
        );

        final filter = const InventoryFilter(
          status: 'all',
          search: 'beans',
          lowStock: true,
          page: 1,
          perPage: 25,
        );

        final result = await repo.getItems(filter);

        expect(captured.url.path, equals('/api/v1/inventory/items'));
        expect(captured.url.queryParameters['status'], equals('all'));
        expect(captured.url.queryParameters['search'], equals('beans'));
        expect(captured.url.queryParameters['low_stock'], equals('1'));
        expect(
          captured.headers['Authorization'],
          equals('Bearer secret-token-xyz'),
        );
        expect(result.items.length, equals(1));
      },
    );

    test('createItem issues POST with exact body and authorization', () async {
      late http.Request captured;

      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'data': sampleItemJson()}), 201);
      });

      final repo = ApiInventoryRepository(
        client: ApiClient(client: mock, baseUrl: 'https://api.test/api/v1'),
        token: 'secret-token-xyz',
      );

      final item = await repo.createItem(
        sku: 'beans',
        name: 'Coffee Beans',
        baseUnit: BaseUnit.g,
        reorderLevel: ExactQuantity.parse('1000.0000'),
      );

      expect(captured.method, equals('POST'));
      expect(captured.url.path, equals('/api/v1/inventory/items'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['sku'], equals('BEANS')); // Uppercase normalized
      expect(body['base_unit'], equals('g'));
      expect(body['reorder_level'], equals('1000.0000'));
      expect(item.id, equals(1));
    });

    test('createMovement sends Idempotency-Key and payload', () async {
      late http.Request captured;

      final mock = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': {
              'id': 50,
              'inventory_item_id': 1,
              'order_id': null,
              'actor_id': 2,
              'quantity_delta': '1000.0000',
              'reason': 'receipt',
              'note': 'Order arrival',
              'created_at': '2026-10-14T10:00:00+00:00',
            },
          }),
          201,
        );
      });

      final repo = ApiInventoryRepository(
        client: ApiClient(client: mock, baseUrl: 'https://api.test/api/v1'),
        token: 'secret-token-xyz',
      );

      final intent = StockMovementIntent(
        inventoryItemId: 1,
        reason: StockMovementReason.receipt,
        quantityDelta: ExactQuantity.parse('1000.0000'),
        note: 'Order arrival',
        idempotencyKey: 'mov_key_12345678',
      );

      final movement = await repo.createMovement(intent);

      expect(captured.method, equals('POST'));
      expect(captured.url.path, equals('/api/v1/inventory/items/1/movements'));
      expect(captured.headers['Idempotency-Key'], equals('mov_key_12345678'));
      expect(movement.id, equals(50));
    });

    test(
      'replaceRecipe issues PUT request with atomic ingredients list',
      () async {
        late http.Request captured;

        final mock = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'data': {
                'product_id': 5,
                'ingredients': [
                  {
                    'inventory_item_id': 1,
                    'sku': 'BEANS',
                    'name': 'Coffee Beans',
                    'base_unit': 'g',
                    'is_active': true,
                    'quantity': '18.0000',
                  },
                ],
              },
            }),
            200,
          );
        });

        final repo = ApiInventoryRepository(
          client: ApiClient(client: mock, baseUrl: 'https://api.test/api/v1'),
          token: 'secret-token-xyz',
        );

        final recipe = await repo.replaceRecipe(5, [
          RecipeIngredientPayload(
            inventoryItemId: 1,
            quantity: ExactQuantity.parse('18.0000'),
          ),
        ]);

        expect(captured.method, equals('PUT'));
        expect(captured.url.path, equals('/api/v1/products/5/recipe'));
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['ingredients'], isList);
        expect((body['ingredients'] as List).length, equals(1));
        expect(recipe.productId, equals(5));
      },
    );

    test('maps 401, 403, 404, 409, 422 to typed InventoryFailure', () async {
      Future<void> expectFailure(
        int status,
        String body,
        InventoryFailureKind kind,
      ) async {
        final mock = MockClient((_) async => http.Response(body, status));
        final repo = ApiInventoryRepository(
          client: ApiClient(client: mock, baseUrl: 'https://api.test/api/v1'),
          token: 'token',
        );

        try {
          await repo.getItem(1);
          fail('Should have thrown');
        } on InventoryFailure catch (e) {
          expect(e.kind, equals(kind));
        }
      }

      await expectFailure(
        401,
        jsonEncode({'message': 'Unauthenticated'}),
        InventoryFailureKind.sessionExpired,
      );
      await expectFailure(
        403,
        jsonEncode({'message': 'Forbidden'}),
        InventoryFailureKind.forbidden,
      );
      await expectFailure(
        404,
        jsonEncode({'message': 'Not found'}),
        InventoryFailureKind.notFound,
      );
      await expectFailure(
        409,
        jsonEncode({'message': 'Conflict'}),
        InventoryFailureKind.conflict,
      );
      await expectFailure(
        422,
        jsonEncode({
          'message': 'Invalid',
          'errors': {
            'sku': ['Taken'],
          },
        }),
        InventoryFailureKind.validation,
      );
    });
  });
}
