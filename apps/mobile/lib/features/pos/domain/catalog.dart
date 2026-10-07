/// Plain Dart catalog values. Prices are bounded exact USD cents.
class CatalogCategory {
  CatalogCategory({
    required this.id,
    required this.name,
    required this.isActive,
  }) {
    if (id <= 0 || id > maxExactId || name.trim().isEmpty) {
      throw ArgumentError('Invalid category.');
    }
  }

  // JSON numbers above this boundary cannot retain identity on Dart web.
  static const maxExactId = 9007199254740991;
  final int id;
  final String name;
  final bool isActive;
}

class CatalogProduct {
  CatalogProduct({
    required this.id,
    required this.category,
    required this.sku,
    required this.name,
    required this.priceMinor,
    required this.isActive,
    required this.isSellable,
    this.description,
  }) {
    if (id <= 0 ||
        id > CatalogCategory.maxExactId ||
        sku.trim().isEmpty ||
        name.trim().isEmpty ||
        priceMinor < 0 ||
        priceMinor > 999999 ||
        isSellable != (isActive && category.isActive)) {
      throw ArgumentError('Invalid product.');
    }
  }

  final int id;
  final CatalogCategory category;
  final String sku;
  final String name;
  final String? description;
  final int priceMinor;
  final bool isActive;
  final bool isSellable;
  String get currency => 'USD';
}

/// Only numeric pagination travels inward; server URLs are never followed.
class CatalogPage<T> {
  CatalogPage({
    required List<T> items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  }) : items = List.unmodifiable(items);

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  bool get hasMore => currentPage < lastPage && currentPage < 10000;
}
