import 'package:flutter/foundation.dart';

/// Immutable query filter criteria for retrieving inventory items.
///
/// Ensures only backend-supported query parameters (`status`, `search`, `low_stock`,
/// `page`, `per_page`) are constructed to prevent 422 RejectsUnknownFields errors.
@immutable
class InventoryFilter {
  const InventoryFilter({
    this.status = 'active',
    this.search,
    this.lowStock,
    this.page = 1,
    this.perPage = 25,
  }) : assert(
         status == 'active' || status == 'inactive' || status == 'all',
         'Status must be active, inactive, or all.',
       ),
       assert(page >= 1 && page <= 10000, 'Page must be between 1 and 10000.'),
       assert(
         perPage >= 1 && perPage <= 100,
         'PerPage must be between 1 and 100.',
       );

  final String status;
  final String? search;
  final bool? lowStock;
  final int page;
  final int perPage;

  /// Default initial filter (active items, page 1, perPage 25).
  static const InventoryFilter initial = InventoryFilter();

  /// Serializes into strictly allowlisted query parameters.
  Map<String, String> toQueryParameters() {
    final params = <String, String>{};

    if (status != 'active') {
      params['status'] = status;
    }

    if (search != null) {
      final trimmed = search!.trim();
      if (trimmed.isNotEmpty) {
        // Enforce backend 80 characters max
        params['search'] = trimmed.length > 80
            ? trimmed.substring(0, 80)
            : trimmed;
      }
    }

    if (lowStock != null) {
      params['low_stock'] = lowStock! ? '1' : '0';
    }

    if (page > 1) {
      params['page'] = page.toString();
    }

    if (perPage != 25) {
      params['per_page'] = perPage.toString();
    }

    return params;
  }

  InventoryFilter copyWith({
    String? status,
    String? search,
    bool? clearSearch,
    bool? lowStock,
    bool? clearLowStock,
    int? page,
    int? perPage,
  }) {
    return InventoryFilter(
      status: status ?? this.status,
      search: clearSearch == true ? null : (search ?? this.search),
      lowStock: clearLowStock == true ? null : (lowStock ?? this.lowStock),
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryFilter &&
          other.status == status &&
          other.search == search &&
          other.lowStock == lowStock &&
          other.page == page &&
          other.perPage == perPage);

  @override
  int get hashCode => Object.hash(status, search, lowStock, page, perPage);

  @override
  String toString() =>
      'InventoryFilter(status: $status, search: $search, lowStock: $lowStock, page: $page, perPage: $perPage)';
}
