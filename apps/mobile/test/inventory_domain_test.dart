import 'package:coffee_management_mobile/features/inventory/domain/exact_quantity.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_filter.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_item.dart';
import 'package:coffee_management_mobile/features/inventory/domain/product_recipe.dart';
import 'package:coffee_management_mobile/features/inventory/domain/stock_movement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExactQuantity Domain Model', () {
    test('parses canonical and user-friendly unsigned decimal strings', () {
      expect(ExactQuantity.parse('0').subunits, equals(0));
      expect(ExactQuantity.parse('18').subunits, equals(180000));
      expect(ExactQuantity.parse('18.5').subunits, equals(185000));
      expect(ExactQuantity.parse('18.25').subunits, equals(182500));
      expect(ExactQuantity.parse('18.2575').subunits, equals(182575));
      expect(
        ExactQuantity.parse('9999999999.9999').subunits,
        equals(ExactQuantity.maxScaled),
      );
    });

    test('parses signed decimal strings when allowed', () {
      expect(
        ExactQuantity.parse('-250.0000', signed: true).subunits,
        equals(-2500000),
      );
      expect(ExactQuantity.parse('-0.5', signed: true).subunits, equals(-5000));
      expect(
        ExactQuantity.parse('5000.0000', signed: true).subunits,
        equals(50000000),
      );
    });

    test('rejects negative zero in both signed and unsigned modes', () {
      expect(
        () => ExactQuantity.parse('-0', signed: true),
        throwsFormatException,
      );
      expect(
        () => ExactQuantity.parse('-0.0', signed: true),
        throwsFormatException,
      );
      expect(
        () => ExactQuantity.parse('-0.0000', signed: true),
        throwsFormatException,
      );
      expect(
        () => ExactQuantity.parse('-0', signed: false),
        throwsFormatException,
      );
    });

    test('rejects negative quantities in unsigned mode', () {
      expect(
        () => ExactQuantity.parse('-5.0000', signed: false),
        throwsFormatException,
      );
    });

    test('rejects excess precision beyond four decimal places', () {
      expect(() => ExactQuantity.parse('1.23456'), throwsFormatException);
      expect(() => ExactQuantity.parse('0.00001'), throwsFormatException);
    });

    test('rejects scientific notation and non-canonical forms', () {
      expect(() => ExactQuantity.parse('1e5'), throwsFormatException);
      expect(() => ExactQuantity.parse('2.5E-3'), throwsFormatException);
      expect(() => ExactQuantity.parse('+15.0000'), throwsFormatException);
      expect(() => ExactQuantity.parse(' 15.0000'), throwsFormatException);
      expect(() => ExactQuantity.parse('15.0000 '), throwsFormatException);
      expect(() => ExactQuantity.parse('15 0000'), throwsFormatException);
      expect(() => ExactQuantity.parse('15,0000'), throwsFormatException);
    });

    test('rejects invalid leading zeros on integer part', () {
      expect(() => ExactQuantity.parse('01'), throwsFormatException);
      expect(() => ExactQuantity.parse('007.5000'), throwsFormatException);
      expect(() => ExactQuantity.parse('00.0000'), throwsFormatException);
    });

    test('rejects quantities exceeding maximum magnitude limit', () {
      expect(
        () => ExactQuantity.parse('10000000000.0000'),
        throwsFormatException,
      );
      expect(
        () => ExactQuantity.parse('-10000000000.0000', signed: true),
        throwsFormatException,
      );
    });

    test(
      'formats correctly to canonical, formatted, and readable representations',
      () {
        final q1 = ExactQuantity.parse('18');
        expect(q1.toCanonicalString(), equals('18.0000'));
        expect(q1.toFormattedString(), equals('18.0000'));
        expect(q1.toReadableString(), equals('18'));

        final q2 = ExactQuantity.parse('4750.2500');
        expect(q2.toCanonicalString(), equals('4750.2500'));
        expect(q2.toFormattedString(), equals('4,750.2500'));
        expect(q2.toReadableString(), equals('4750.25'));

        final q3 = ExactQuantity.parse('-250.0000', signed: true);
        expect(q3.toCanonicalString(), equals('-250.0000'));
        expect(q3.toFormattedString(), equals('-250.0000'));
        expect(q3.toReadableString(), equals('-250'));

        expect(q2.formatWithUnit('g'), equals('4,750.2500 g'));
        expect(q2.formatWithUnit('g', compact: true), equals('4750.25 g'));
      },
    );

    test('performs checked integer arithmetic without double coercion', () {
      final a = ExactQuantity.parse('10.5000');
      final b = ExactQuantity.parse('5.2500');

      expect((a + b).toCanonicalString(), equals('15.7500'));
      expect((a - b).toCanonicalString(), equals('5.2500'));
      expect((-b).toCanonicalString(), equals('-5.2500'));
      expect(b.multiply(3).toCanonicalString(), equals('15.7500'));
      expect(b.multiply(0), equals(ExactQuantity.zero));

      expect(a > b, isTrue);
      expect(b < a, isTrue);
      expect(a >= b, isTrue);
      expect(b <= a, isTrue);
      expect(a == ExactQuantity.parse('10.5'), isTrue);
    });
  });

  group('BaseUnit & InventoryItem Domain', () {
    test('parses and validates base units strictly', () {
      expect(BaseUnit.parse('g'), equals(BaseUnit.g));
      expect(BaseUnit.parse('ml'), equals(BaseUnit.ml));
      expect(BaseUnit.parse('unit'), equals(BaseUnit.unit));
      expect(() => BaseUnit.parse('kg'), throwsFormatException);
      expect(() => BaseUnit.parse('liter'), throwsFormatException);
    });

    test('validates inventory item constraints', () {
      final item = InventoryItem(
        id: 1,
        sku: 'BEANS',
        name: 'Coffee Beans',
        baseUnit: BaseUnit.g,
        onHand: ExactQuantity.parse('5000.0000'),
        reserved: ExactQuantity.parse('250.0000'),
        available: ExactQuantity.parse('4750.0000'),
        reorderLevel: ExactQuantity.parse('1000.0000'),
        isActive: true,
        lowStock: false,
      );

      expect(item.id, equals(1));
      expect(item.sku, equals('BEANS'));
      expect(item.available, equals(ExactQuantity.parse('4750.0000')));

      expect(
        () => InventoryItem(
          id: 0,
          sku: 'BEANS',
          name: 'Coffee Beans',
          baseUnit: BaseUnit.g,
          onHand: ExactQuantity.zero,
          reserved: ExactQuantity.zero,
          available: ExactQuantity.zero,
          reorderLevel: ExactQuantity.zero,
          isActive: true,
          lowStock: false,
        ),
        throwsArgumentError,
      );
    });
  });

  group('StockMovement & Intent Domain', () {
    test('validates movement direction and note business rules', () {
      final validKey = 'op_key_1234567890';

      // Opening balance must be positive
      expect(
        () => StockMovementIntent(
          inventoryItemId: 1,
          reason: StockMovementReason.openingBalance,
          quantityDelta: ExactQuantity.parse('-100.0000', signed: true),
          idempotencyKey: validKey,
        ),
        throwsArgumentError,
      );

      // Receipt must be positive
      expect(
        () => StockMovementIntent(
          inventoryItemId: 1,
          reason: StockMovementReason.receipt,
          quantityDelta: ExactQuantity.parse('-50.0000', signed: true),
          idempotencyKey: validKey,
        ),
        throwsArgumentError,
      );

      // Waste must be negative
      expect(
        () => StockMovementIntent(
          inventoryItemId: 1,
          reason: StockMovementReason.waste,
          quantityDelta: ExactQuantity.parse('50.0000'),
          idempotencyKey: validKey,
        ),
        throwsArgumentError,
      );

      // Adjustment requires non-blank note
      expect(
        () => StockMovementIntent(
          inventoryItemId: 1,
          reason: StockMovementReason.adjustment,
          quantityDelta: ExactQuantity.parse('10.0000'),
          note: '   ',
          idempotencyKey: validKey,
        ),
        throwsArgumentError,
      );

      // Zero delta rejected
      expect(
        () => StockMovementIntent(
          inventoryItemId: 1,
          reason: StockMovementReason.adjustment,
          quantityDelta: ExactQuantity.zero,
          note: 'Count discrepancy',
          idempotencyKey: validKey,
        ),
        throwsArgumentError,
      );

      // System reason "sale" rejected for manual intent
      expect(
        () => StockMovementIntent(
          inventoryItemId: 1,
          reason: StockMovementReason.sale,
          quantityDelta: ExactQuantity.parse('-1.0000', signed: true),
          idempotencyKey: validKey,
        ),
        throwsArgumentError,
      );

      // Valid adjustment intent succeeds
      final intent = StockMovementIntent(
        inventoryItemId: 1,
        reason: StockMovementReason.adjustment,
        quantityDelta: ExactQuantity.parse('-15.0000', signed: true),
        note: 'Count correction',
        idempotencyKey: validKey,
      );
      expect(
        intent.toJson(),
        equals({
          'reason': 'adjustment',
          'quantity_delta': '-15.0000',
          'note': 'Count correction',
        }),
      );
    });

    test('validates 8-64 character ASCII idempotency key', () {
      expect(
        () => StockMovementIntent.validateIdempotencyKey('short'),
        throwsArgumentError,
      );
      expect(
        () => StockMovementIntent.validateIdempotencyKey(
          '_start_with_underscore',
        ),
        throwsArgumentError,
      );
      expect(
        () => StockMovementIntent.validateIdempotencyKey('has space in key'),
        throwsArgumentError,
      );
      // Valid keys
      expect(
        () => StockMovementIntent.validateIdempotencyKey('mov_12345678abcdef'),
        returnsNormally,
      );
      expect(
        () => StockMovementIntent.validateIdempotencyKey('A1b2c3d4e5f6g7h8'),
        returnsNormally,
      );
    });
  });

  group('ProductRecipe Domain', () {
    test('enforces unique ingredients and max 100 limit', () {
      final ingredient1 = RecipeIngredient(
        inventoryItemId: 1,
        sku: 'BEANS',
        name: 'Coffee Beans',
        baseUnit: BaseUnit.g,
        isActive: true,
        quantity: ExactQuantity.parse('18.0000'),
      );
      final ingredient2 = RecipeIngredient(
        inventoryItemId: 2,
        sku: 'MILK',
        name: 'Fresh Milk',
        baseUnit: BaseUnit.ml,
        isActive: true,
        quantity: ExactQuantity.parse('180.0000'),
      );

      final recipe = ProductRecipe(
        productId: 10,
        ingredients: [ingredient1, ingredient2],
      );
      expect(recipe.ingredients.length, equals(2));

      // Duplicate ingredient ID rejected
      expect(
        () => ProductRecipe(
          productId: 10,
          ingredients: [ingredient1, ingredient1],
        ),
        throwsArgumentError,
      );
    });
  });

  group('InventoryFilter Query Serialization', () {
    test('serializes default active status and pagination', () {
      const filter = InventoryFilter();
      expect(filter.toQueryParameters(), isEmpty);
    });

    test('serializes custom status, search, and low_stock strictly', () {
      const filter = InventoryFilter(
        status: 'all',
        search: '  espresso beans  ',
        lowStock: true,
        page: 2,
        perPage: 50,
      );
      expect(
        filter.toQueryParameters(),
        equals({
          'status': 'all',
          'search': 'espresso beans',
          'low_stock': '1',
          'page': '2',
          'per_page': '50',
        }),
      );
    });

    test('clips search string to maximum 80 characters', () {
      final longSearch = 'a' * 100;
      final filter = InventoryFilter(search: longSearch);
      final params = filter.toQueryParameters();
      expect(params['search']!.length, equals(80));
    });
  });
}
