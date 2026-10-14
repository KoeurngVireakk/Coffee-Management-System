import '../../pos/domain/order.dart';
import '../../pos/domain/payment.dart';

/// Immutable page of orders returned by the order history API.
class OrderPage {
  OrderPage({
    required List<Order> items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  }) : items = List.unmodifiable(items);

  final List<Order> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage && currentPage < 10000;
}

enum OrderHistoryFailureKind {
  sessionExpired,
  forbidden,
  notFound,
  conflict,
  validation,
  rateLimited,
  network,
  server,
  invalidResponse,
}

class OrderHistoryFailure implements Exception {
  const OrderHistoryFailure(
    this.kind, {
    this.detail,
    this.errors = const {},
    this.retryAfterSeconds,
  });

  final OrderHistoryFailureKind kind;
  final String? detail;
  final Map<String, List<String>> errors;
  final int? retryAfterSeconds;

  String? fieldMessage(String field) => errors[field]?.firstOrNull;

  String get message => switch (kind) {
    OrderHistoryFailureKind.sessionExpired =>
      'Your session has expired. Please sign in again.',
    OrderHistoryFailureKind.forbidden =>
      'You do not have permission to view these orders. Contact your manager.',
    OrderHistoryFailureKind.notFound =>
      'The requested order is unavailable or does not exist.',
    OrderHistoryFailureKind.conflict =>
      detail ?? 'The order state changed on the server. Please refresh.',
    OrderHistoryFailureKind.validation =>
      fieldMessage('status') ??
          fieldMessage('created_from') ??
          fieldMessage('created_to') ??
          fieldMessage('page') ??
          fieldMessage('per_page') ??
          'Invalid filter criteria. Please check your inputs.',
    OrderHistoryFailureKind.rateLimited =>
      'Too many requests. Please wait before refreshing.',
    OrderHistoryFailureKind.network =>
      'Unable to connect to the server. Check your network connection.',
    OrderHistoryFailureKind.server =>
      'The order service encountered an error. Please try again shortly.',
    OrderHistoryFailureKind.invalidResponse =>
      'Received an invalid response from the server.',
  };
}

/// Abstract contract for querying persisted order history and authorized order details.
abstract interface class OrderHistoryRepository {
  /// Fetches a paginated list of orders matching the given criteria.
  Future<OrderPage> orders({
    OrderStatus? status,
    DateTime? createdFrom,
    DateTime? createdTo,
    int page = 1,
    int perPage = 25,
  });

  /// Fetches authoritative single order details by public reference.
  Future<Order> order(String reference);

  /// Fetches payment attempts associated with the given order.
  Future<PaymentPage> payments(
    String reference, {
    int page = 1,
    int perPage = 25,
  });
}
