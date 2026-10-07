import 'catalog.dart';

enum CartLimit { quantity, lines, unavailable }

class CartLine {
  const CartLine._(this.product, this.quantity);
  final CatalogProduct product;
  final int quantity;
  int get subtotalMinor => product.priceMinor * quantity;
}

/// Insertion order is stable. All mutations enforce the frozen checkout bounds.
class Cart {
  static const maxLines = 50;
  static const maxQuantity = 99;
  final Map<int, CartLine> _lines = {};

  List<CartLine> get lines => List.unmodifiable(_lines.values);
  int get distinctCount => _lines.length;
  int get itemCount =>
      _lines.values.fold(0, (sum, line) => sum + line.quantity);
  int get subtotalMinor =>
      _lines.values.fold(0, (sum, line) => sum + line.subtotalMinor);
  int get totalMinor => subtotalMinor;
  int quantityFor(int id) => _lines[id]?.quantity ?? 0;

  CartLimit? add(CatalogProduct product) {
    if (!product.isSellable) return CartLimit.unavailable;
    final current = _lines[product.id];
    if (current != null && current.quantity == maxQuantity) {
      return CartLimit.quantity;
    }
    if (current == null && distinctCount == maxLines) return CartLimit.lines;
    _lines[product.id] = CartLine._(product, (current?.quantity ?? 0) + 1);
    return null;
  }

  CartLimit? increment(int id) {
    final line = _lines[id];
    return line == null ? CartLimit.unavailable : add(line.product);
  }

  // At one, decrement is a no-op; the explicit Remove action removes the line.
  void decrement(int id) {
    final line = _lines[id];
    if (line != null && line.quantity > 1) {
      _lines[id] = CartLine._(line.product, line.quantity - 1);
    }
  }

  void remove(int id) => _lines.remove(id);
  void clear() => _lines.clear();

  /// Update previews only for returned products. Absence in a page says nothing
  /// about an existing line's sellability. Phase 5 must revalidate all lines.
  void updatePreviews(Iterable<CatalogProduct> products) {
    for (final product in products) {
      final line = _lines[product.id];
      if (line != null) _lines[product.id] = CartLine._(product, line.quantity);
    }
  }
}
