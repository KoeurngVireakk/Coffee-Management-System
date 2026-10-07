import 'package:coffee_management_mobile/features/pos/domain/catalog.dart';
import 'package:coffee_management_mobile/features/pos/domain/catalog_repository.dart';

CatalogCategory category({int id = 1, String name = 'Coffee'}) =>
    CatalogCategory(id: id, name: name, isActive: true);
CatalogProduct product({
  int id = 1,
  String name = 'Cappuccino',
  int cents = 325,
}) => CatalogProduct(
  id: id,
  category: category(),
  sku: 'COFFEE-$id',
  name: name,
  priceMinor: cents,
  isActive: true,
  isSellable: true,
);
CatalogPage<T> page<T>(
  List<T> items, {
  int current = 1,
  int last = 1,
  int? total,
}) => CatalogPage(
  items: items,
  currentPage: current,
  lastPage: last,
  perPage: 25,
  total: total ?? items.length,
);

class FakeCatalogRepository implements CatalogRepository {
  Future<CatalogPage<CatalogCategory>> Function(int)? onCategories;
  Future<CatalogPage<CatalogProduct>> Function(int, int?, String)? onProducts;
  final productRequests = <({int page, int? categoryId, String search})>[];
  final categoryRequests = <int>[];
  @override
  Future<CatalogPage<CatalogCategory>> categories({int page = 1}) async {
    categoryRequests.add(page);
    return onCategories?.call(page) ??
        Future.value(
          CatalogPage(
            items: [category()],
            currentPage: page,
            lastPage: 1,
            perPage: 50,
            total: 1,
          ),
        );
  }

  @override
  Future<CatalogPage<CatalogProduct>> products({
    int page = 1,
    int? categoryId,
    String search = '',
  }) async {
    productRequests.add((page: page, categoryId: categoryId, search: search));
    return onProducts?.call(page, categoryId, search) ??
        Future.value(
          CatalogPage(
            items: [product()],
            currentPage: page,
            lastPage: 1,
            perPage: 25,
            total: 1,
          ),
        );
  }
}

Map<String, dynamic> categoryJson() => {
  'id': 1,
  'name': 'Coffee',
  'is_active': true,
  'created_at': null,
  'updated_at': null,
};
Map<String, dynamic> productJson() => {
  'id': 1,
  'category_id': 1,
  'category': {'id': 1, 'name': 'Coffee', 'is_active': true},
  'sku': 'COFFEE-1',
  'name': 'Cappuccino',
  'description': null,
  'price_minor': '325',
  'currency': 'USD',
  'is_active': true,
  'is_sellable': true,
  'created_at': null,
  'updated_at': null,
};
Map<String, dynamic> pageJson(
  List<Object> items, {
  int current = 1,
  int size = 25,
  int? total,
}) {
  final count = total ?? items.length;
  final last = count == 0 ? 1 : (count + size - 1) ~/ size;
  const url = 'https://api.example.test/api/v1/products';
  return {
    'data': items,
    'links': {
      'first': '$url?page=1',
      'last': '$url?page=$last',
      'prev': current > 1 ? '$url?page=${current - 1}' : null,
      'next': current < last ? '$url?page=${current + 1}' : null,
    },
    'meta': {
      'current_page': current,
      'last_page': last,
      'per_page': size,
      'total': count,
      'from': items.isEmpty ? null : (current - 1) * size + 1,
      'to': items.isEmpty ? null : (current - 1) * size + items.length,
      'path': url,
      'links': [],
    },
  };
}
