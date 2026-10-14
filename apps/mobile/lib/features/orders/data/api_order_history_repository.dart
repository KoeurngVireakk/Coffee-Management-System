import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../pos/data/catalog_dto.dart';
import '../../pos/data/checkout_dto.dart';
import '../../pos/domain/order.dart';
import '../../pos/domain/payment.dart';
import '../domain/order_filter.dart';
import '../domain/order_history_repository.dart';
import 'order_history_dto.dart';

/// Production implementation of [OrderHistoryRepository] consuming the frozen Laravel API.
class ApiOrderHistoryRepository implements OrderHistoryRepository {
  ApiOrderHistoryRepository({required this.client, required this.token});

  final ApiClient client;
  final String token;

  String _path(String reference) =>
      '/orders/${CheckoutDto.reference(reference)}';

  @override
  Future<OrderPage> orders({
    OrderStatus? status,
    DateTime? createdFrom,
    DateTime? createdTo,
    int page = 1,
    int perPage = 25,
  }) => _request(() async {
    final filter = OrderFilter(
      status: status,
      createdFrom: createdFrom,
      createdTo: createdTo,
    );
    final params = filter.toQueryParameters(page: page, perPage: perPage);

    final json = await client.get(
      '/orders',
      token: token,
      queryParameters: params,
    );

    return OrderHistoryDto.orderPage(
      json,
      requestedPage: page,
      requestedPerPage: perPage,
    );
  });

  @override
  Future<Order> order(String reference) => _request(() async {
    final json = await client.get(_path(reference), token: token);
    final result = CheckoutDto.order(CatalogDto.object(json)['data']);
    if (result.reference != reference) {
      throw const FormatException('Returned order reference mismatch.');
    }
    return result;
  });

  @override
  Future<PaymentPage> payments(
    String reference, {
    int page = 1,
    int perPage = 25,
  }) => _request(() async {
    if (page < 1 || page > 10000) {
      throw ArgumentError.value(page, 'page', 'Invalid page number.');
    }
    if (perPage < 1 || perPage > 100) {
      throw ArgumentError.value(perPage, 'perPage', 'Invalid perPage limit.');
    }

    final json = await client.get(
      '${_path(reference)}/payments',
      token: token,
      queryParameters: {'page': '$page', 'per_page': '$perPage'},
    );

    return OrderHistoryDto.paymentPage(
      json,
      requestedPage: page,
      requestedPerPage: perPage,
    );
  });

  String _safeMessage(String value) {
    final safe = value
        .replaceAll(token, '[redacted]')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .trim();
    return safe.substring(0, safe.length.clamp(0, 300));
  }

  Future<T> _request<T>(Future<T> Function() send) async {
    try {
      return await send();
    } on UnauthorizedException {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.sessionExpired);
    } on ForbiddenException {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.forbidden);
    } on NotFoundException {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.notFound);
    } on ConflictException catch (e) {
      throw OrderHistoryFailure(
        OrderHistoryFailureKind.conflict,
        detail: _safeMessage(e.message),
      );
    } on ValidationException catch (e) {
      throw OrderHistoryFailure(
        OrderHistoryFailureKind.validation,
        errors: Map.unmodifiable({
          for (final entry in e.errors.entries)
            entry.key: List<String>.unmodifiable(entry.value.map(_safeMessage)),
        }),
      );
    } on RateLimitedException catch (e) {
      throw OrderHistoryFailure(
        OrderHistoryFailureKind.rateLimited,
        retryAfterSeconds: e.retryAfterSeconds,
      );
    } on ServerException {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.server);
    } on NetworkException {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.network);
    } on ApiException {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.invalidResponse);
    } on FormatException {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.invalidResponse);
    }
  }
}
