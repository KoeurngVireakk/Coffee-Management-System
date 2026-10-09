import 'dart:math';
import 'cart.dart';
import 'catalog.dart';

class CheckoutItem {
  CheckoutItem({required this.productId, required this.quantity}) {
    if (productId < 1 ||
        productId > CatalogCategory.maxExactId ||
        quantity < 1 ||
        quantity > Cart.maxQuantity) {
      throw ArgumentError('Invalid checkout line.');
    }
  }
  final int productId;
  final int quantity;
}

class CheckoutIntent {
  CheckoutIntent({
    required this.key,
    required List<CheckoutItem> items,
    required this.previewTotalMinor,
  }) : items = List.unmodifiable(
         [...items]..sort((a, b) => a.productId.compareTo(b.productId)),
       ) {
    if (items.isEmpty ||
        items.length > Cart.maxLines ||
        items.map((item) => item.productId).toSet().length != items.length) {
      throw ArgumentError('Invalid checkout intent.');
    }
    OperationKey.validate(key);
  }
  final String key;
  final List<CheckoutItem> items;
  final int previewTotalMinor;

  bool matchesCart(Cart cart) =>
      cart.distinctCount == items.length &&
      items.every((item) => cart.quantityFor(item.productId) == item.quantity);
}

abstract final class OperationKey {
  static void validate(String key) {
    if (RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{7,63}$').stringMatch(key) != key) {
      throw ArgumentError('Invalid operation key.');
    }
  }

  /// 128 random bits; fail closed if secure randomness is unavailable.
  static String generate() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
