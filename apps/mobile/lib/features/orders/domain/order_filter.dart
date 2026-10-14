import '../../pos/domain/order.dart';

/// Immutable filter criteria for order history queries.
///
/// Ensures only API-allowlisted query parameters are produced and
/// validates date boundary consistency (`created_from <= created_to`).
class OrderFilter {
  OrderFilter({this.status, this.createdFrom, this.createdTo}) {
    if (createdFrom != null &&
        createdTo != null &&
        createdFrom!.isAfter(createdTo!)) {
      throw ArgumentError(
        'The upper boundary (created_to) must be at or after created_from.',
      );
    }
  }

  final OrderStatus? status;
  final DateTime? createdFrom;
  final DateTime? createdTo;

  bool get isActive =>
      status != null || createdFrom != null || createdTo != null;

  bool get hasDateFilter => createdFrom != null || createdTo != null;

  factory OrderFilter.calendarDay(DateTime day) =>
      OrderFilter(createdFrom: startOfDay(day), createdTo: endOfDay(day));

  factory OrderFilter.calendarRange(DateTime from, DateTime to) =>
      OrderFilter(createdFrom: startOfDay(from), createdTo: endOfDay(to));

  OrderFilter copyWith({
    OrderStatus? Function()? status,
    DateTime? Function()? createdFrom,
    DateTime? Function()? createdTo,
  }) {
    return OrderFilter(
      status: status != null ? status() : this.status,
      createdFrom: createdFrom != null ? createdFrom() : this.createdFrom,
      createdTo: createdTo != null ? createdTo() : this.createdTo,
    );
  }

  OrderFilter clear() => OrderFilter();

  /// Converts this filter to query parameters for `GET /api/v1/orders`.
  ///
  /// Strictly outputs only allowlisted fields: `status`, `created_from`,
  /// `created_to`, `page`, and `per_page`.
  Map<String, String> toQueryParameters({int page = 1, int perPage = 25}) {
    if (page < 1 || page > 10000) {
      throw ArgumentError.value(
        page,
        'page',
        'Page must be between 1 and 10000.',
      );
    }
    if (perPage < 1 || perPage > 100) {
      throw ArgumentError.value(
        perPage,
        'perPage',
        'per_page must be between 1 and 100.',
      );
    }

    final params = <String, String>{};

    if (status != null) {
      params['status'] = statusToApi(status!);
    }

    if (createdFrom != null) {
      params['created_from'] = createdFrom!.toUtc().toIso8601String();
    }

    if (createdTo != null) {
      params['created_to'] = createdTo!.toUtc().toIso8601String();
    }

    params['page'] = '$page';
    params['per_page'] = '$perPage';

    return Map.unmodifiable(params);
  }

  /// Maps [OrderStatus] enum to backend string representation.
  static String statusToApi(OrderStatus status) => switch (status) {
    OrderStatus.pendingPayment => 'pending_payment',
    OrderStatus.paid => 'paid',
    OrderStatus.cancelled => 'cancelled',
    OrderStatus.expired => 'expired',
  };

  /// Parses backend string representation to [OrderStatus] enum.
  static OrderStatus? apiToStatus(String value) => switch (value) {
    'pending_payment' => OrderStatus.pendingPayment,
    'paid' => OrderStatus.paid,
    'cancelled' => OrderStatus.cancelled,
    'expired' => OrderStatus.expired,
    _ => null,
  };

  /// Returns the start of the calendar day for [date] in device local time.
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 0, 0, 0);

  /// Returns the end of the calendar day for [date] in device local time.
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderFilter &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          createdFrom == other.createdFrom &&
          createdTo == other.createdTo;

  @override
  int get hashCode => Object.hash(status, createdFrom, createdTo);
}
