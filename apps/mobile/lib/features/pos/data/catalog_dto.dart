import '../domain/catalog.dart';

/// Strict decoding at the API boundary; no financial or identity defaults.
abstract final class CatalogDto {
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected object.');
    }
    return value;
  }

  static int integer(
    Object? value, {
    int min = 1,
    int max = CatalogCategory.maxExactId,
  }) {
    if (value is! int || value < min || value > max) {
      throw const FormatException('Invalid integer.');
    }
    return value;
  }

  static String text(Object? value, int max) {
    if (value is! String || value.trim().isEmpty || value.runes.length > max) {
      throw const FormatException('Invalid text.');
    }
    return value;
  }

  static bool flag(Object? value) {
    if (value is! bool) throw const FormatException('Invalid flag.');
    return value;
  }

  static void _timestamps(Map<String, dynamic> json) {
    for (final key in ['created_at', 'updated_at']) {
      final value = json[key];
      if (!json.containsKey(key) ||
          (value != null &&
              (value is! String || DateTime.tryParse(value) == null))) {
        throw const FormatException('Invalid timestamp.');
      }
    }
  }

  static CatalogCategory category(Object? value, {bool summary = false}) {
    final json = object(value);
    if (!summary) _timestamps(json);
    return CatalogCategory(
      id: integer(json['id']),
      name: text(json['name'], 120),
      isActive: flag(json['is_active']),
    );
  }

  static int cents(Object? value) {
    if (value is! String ||
        RegExp(r'^(0|[1-9][0-9]{0,5})$').stringMatch(value) != value) {
      throw const FormatException('Invalid USD cents.');
    }
    return int.parse(value);
  }

  static CatalogProduct product(Object? value) {
    final json = object(value);
    _timestamps(json);
    final group = category(json['category'], summary: true);
    if (integer(json['category_id']) != group.id ||
        json['currency'] != 'USD' ||
        !json.containsKey('description') ||
        (json['description'] != null &&
            (json['description'] is! String ||
                (json['description'] as String).runes.length > 2000))) {
      throw const FormatException('Invalid product fields.');
    }
    final sku = text(json['sku'], 64);
    if (RegExp(r'^[A-Z0-9][A-Z0-9_-]*$').stringMatch(sku) != sku) {
      throw const FormatException('Invalid SKU.');
    }
    final active = flag(json['is_active']);
    final sellable = flag(json['is_sellable']);
    if (sellable != (active && group.isActive)) {
      throw const FormatException('Inconsistent sellability.');
    }
    return CatalogProduct(
      id: integer(json['id']),
      category: group,
      sku: sku,
      name: text(json['name'], 160),
      description: json['description'] as String?,
      priceMinor: cents(json['price_minor']),
      isActive: active,
      isSellable: sellable,
    );
  }

  static CatalogPage<T> page<T>(
    Object? value,
    T Function(Object?) decode, {
    required int requestedPage,
    required int requestedPerPage,
  }) {
    final json = object(value);
    final meta = object(json['meta']);
    final links = object(json['links']);
    final data = json['data'];
    if (data is! List) throw const FormatException('Invalid page data.');
    final current = integer(meta['current_page'], max: 10000);
    final last = integer(meta['last_page']);
    final size = integer(meta['per_page'], max: 100);
    final total = integer(meta['total'], min: 0);
    final expectedLast = total == 0 ? 1 : (total - 1) ~/ size + 1;
    final expectedCount = total - (current - 1) * size;
    final count = expectedCount.clamp(0, size);
    for (final key in ['from', 'to']) {
      if (!meta.containsKey(key) || (meta[key] != null && meta[key] is! int)) {
        throw const FormatException('Invalid page offsets.');
      }
    }
    if (current != requestedPage ||
        size != requestedPerPage ||
        last != expectedLast ||
        data.length != count ||
        meta['from'] != (count == 0 ? null : (current - 1) * size + 1) ||
        meta['to'] != (count == 0 ? null : (current - 1) * size + count)) {
      throw const FormatException('Inconsistent pagination.');
    }
    for (final key in ['first', 'last', 'prev', 'next']) {
      final link = links[key];
      if (!links.containsKey(key) ||
          (link != null &&
              (link is! String || Uri.tryParse(link)?.hasAuthority != true))) {
        throw const FormatException('Invalid page links.');
      }
    }
    if (links['first'] == null ||
        links['last'] == null ||
        (links['next'] != null) != (current < last) ||
        (links['prev'] != null) != (current > 1)) {
      throw const FormatException('Inconsistent page links.');
    }
    return CatalogPage(
      items: data.map(decode).toList(),
      currentPage: current,
      lastPage: last,
      perPage: size,
      total: total,
    );
  }
}
