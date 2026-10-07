import 'package:coffee_management_mobile/features/pos/data/catalog_dto.dart';
import 'package:coffee_management_mobile/features/pos/domain/cart.dart';
import 'package:coffee_management_mobile/features/pos/domain/catalog.dart';
import 'package:coffee_management_mobile/shared/theme/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pos_test_support.dart';

void main() {
  test('category and product parse the actual frozen Resource shape', () {
    final group = CatalogDto.category(categoryJson());
    final coffee = CatalogDto.product(productJson());
    expect(group.name, 'Coffee');
    expect(coffee.category.id, group.id);
    expect(coffee.priceMinor, 325);
    expect(coffee.currency, 'USD');
    expect(coffee.description, isNull);
    expect(Formatters.formatCents(coffee.priceMinor), r'$3.25');
  });
  for (final cents in ['0', '1', '325', '999999']) {
    test('canonical cents $cents retain exact value', () {
      expect(CatalogDto.cents(cents), int.parse(cents));
    });
  }
  for (final value in [
    null,
    325,
    3.25,
    '',
    '-1',
    '+1',
    '01',
    '1.0',
    '1e2',
    ' 325',
    '325 ',
    '325\n',
    '325\r\n',
    '1000000',
    '999999999999999999999',
    '٣٢٥',
  ]) {
    test('reject malformed money ${value.runtimeType}: $value', () {
      expect(() => CatalogDto.cents(value), throwsFormatException);
    });
  }
  for (final fields in <Map<String, Object?>>[
    {'id': '1'},
    {'id': 0},
    {'id': 1.0},
    {'id': CatalogCategory.maxExactId + 1},
    {'name': ''},
    {'name': null},
    {'name': List.filled(161, 'a').join()},
    {'currency': 'KHR'},
    {'currency': 'usd'},
    {'currency': null},
    {'category_id': 2},
    {'category': null},
    {
      'category': {'id': 1, 'name': 'Coffee', 'is_active': 1},
    },
    {'is_active': 'true'},
    {'is_sellable': false},
    {'sku': 'bad sku'},
    {'sku': 'COFFEE-1\n'},
    {'description': 7},
    {'created_at': 'bad'},
  ]) {
    test('reject malformed product fields $fields', () {
      expect(
        () => CatalogDto.product({...productJson(), ...fields}),
        throwsFormatException,
      );
    });
  }
  for (final fields in <Map<String, Object?>>[
    {'id': 0},
    {'id': '1'},
    {'name': ''},
    {'name': null},
    {'is_active': 1},
    {'updated_at': []},
  ]) {
    test('reject malformed category fields $fields', () {
      expect(
        () => CatalogDto.category({...categoryJson(), ...fields}),
        throwsFormatException,
      );
    });
  }
  test('required nullable Resource fields must be present', () {
    final missing = productJson()..remove('description');
    expect(() => CatalogDto.product(missing), throwsFormatException);
    expect(
      () => CatalogDto.category(categoryJson()..remove('created_at')),
      throwsFormatException,
    );
  });
  test('cart adds and merges by identity with stable insertion order', () {
    final cart = Cart();
    expect(cart.add(product()), isNull);
    cart.add(product(id: 2, name: 'Tea', cents: 200));
    cart.add(product());
    expect(cart.lines.map((line) => line.product.id), [1, 2]);
    expect(cart.quantityFor(1), 2);
    expect(cart.distinctCount, 2);
    expect(cart.itemCount, 3);
    expect(cart.lines.first.subtotalMinor, 650);
    expect(cart.subtotalMinor, 850);
    expect(cart.totalMinor, cart.subtotalMinor);
    expect(() => cart.lines.clear(), throwsUnsupportedError);
  });
  test('increment, decrement at one, explicit removal, and clear', () {
    final cart = Cart()..add(product());
    cart.increment(1);
    cart.decrement(1);
    cart.decrement(1);
    expect(cart.quantityFor(1), 1);
    cart.remove(1);
    expect(cart.itemCount, 0);
    cart.add(product());
    cart.clear();
    expect(cart.lines, isEmpty);
    expect(cart.subtotalMinor, 0);
    expect(cart.increment(999), CartLimit.unavailable);
  });
  test('quantity limit cannot be bypassed by repeated product taps', () {
    final cart = Cart();
    for (var i = 0; i < 99; i++) {
      expect(cart.add(product()), isNull);
    }
    expect(cart.add(product()), CartLimit.quantity);
    expect(cart.increment(1), CartLimit.quantity);
    expect(cart.quantityFor(1), 99);
    cart.decrement(1);
    expect(cart.increment(1), isNull);
  });
  test('50-line limit permits merging an existing product and later reuse', () {
    final cart = Cart();
    for (var id = 1; id <= 50; id++) {
      expect(cart.add(product(id: id)), isNull);
    }
    expect(cart.add(product(id: 51)), CartLimit.lines);
    expect(cart.add(product(id: 1)), isNull);
    expect(cart.distinctCount, 50);
    cart.remove(1);
    expect(cart.add(product(id: 51)), isNull);
    expect(cart.lines.last.product.id, 51);
  });
  test('maximum entire cart remains exact on web and native', () {
    final cart = Cart();
    for (var id = 1; id <= 50; id++) {
      for (var qty = 0; qty < 99; qty++) {
        cart.add(product(id: id, cents: 999999));
      }
    }
    expect(cart.itemCount, 4950);
    expect(cart.subtotalMinor, 4949995050);
    expect(Formatters.formatCents(cart.subtotalMinor), r'$49499950.50');
  });
  test(
    'preview refresh preserves identity, quantities and unreturned lines',
    () {
      final cart = Cart()
        ..add(product())
        ..add(product())
        ..add(product(id: 2, cents: 101));
      cart.updatePreviews([product(name: 'New name', cents: 450)]);
      expect(cart.lines.first.product.name, 'New name');
      expect(cart.quantityFor(1), 2);
      expect(cart.quantityFor(2), 1);
      expect(cart.subtotalMinor, 1001);
    },
  );
  test('unsellable product never enters cart', () {
    final retired = CatalogProduct(
      id: 1,
      category: category(),
      sku: 'X',
      name: 'Retired',
      priceMinor: 100,
      isActive: false,
      isSellable: false,
    );
    final cart = Cart();
    expect(cart.add(retired), CartLimit.unavailable);
    expect(cart.lines, isEmpty);
  });
}
