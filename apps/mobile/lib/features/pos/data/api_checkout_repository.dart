import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/checkout_intent.dart';
import '../domain/checkout_repository.dart';
import '../domain/exact_money.dart';
import '../domain/order.dart';
import '../domain/payment.dart';
import 'catalog_dto.dart';
import 'checkout_dto.dart';

class ApiCheckoutRepository implements CheckoutRepository {
  ApiCheckoutRepository({required this.client, required this.token});
  final ApiClient client;
  final String token;
  static const paymentPageSize = 100;

  Map<String, String> _headers(String key) {
    OperationKey.validate(key);
    return {'Idempotency-Key': key};
  }

  String _path(String reference) =>
      '/orders/${CheckoutDto.reference(reference)}';

  @override
  Future<Order> createOrder(CheckoutIntent intent) => _request(() async {
    final json = await client.post(
      '/orders',
      token: token,
      headers: _headers(intent.key),
      body: {
        'items': [
          for (final item in intent.items)
            {'product_id': item.productId, 'quantity': item.quantity},
        ],
      },
    );
    final order = CheckoutDto.order(CatalogDto.object(json)['data']);
    if (order.items.length != intent.items.length ||
        intent.items.any(
          (item) => !order.items.any(
            (line) =>
                line.productId == item.productId &&
                line.quantity == item.quantity,
          ),
        )) {
      throw const FormatException('Order does not match the submitted intent.');
    }
    return order;
  });

  @override
  Future<Order> order(String reference) => _request(() async {
    final json = await client.get(_path(reference), token: token);
    final result = CheckoutDto.order(CatalogDto.object(json)['data']);
    if (result.reference != reference) {
      throw const FormatException('Wrong order.');
    }
    return result;
  });

  @override
  Future<Payment> cash(
    String reference, {
    required String key,
    required int tenderMinor,
  }) => _request(() async {
    if (tenderMinor < 0 || tenderMinor > ExactMoney.maxTender) {
      throw ArgumentError('Invalid tender.');
    }
    final json = await client.post(
      '${_path(reference)}/payments/cash',
      token: token,
      headers: _headers(key),
      body: {'tender_minor': '$tenderMinor'},
    );
    final result = CheckoutDto.payment(CatalogDto.object(json)['data']);
    if (result.method != PaymentMethod.cash ||
        result.status != PaymentStatus.confirmed ||
        result.tenderMinor != tenderMinor) {
      throw const FormatException('Wrong cash settlement response.');
    }
    return result;
  });

  @override
  Future<Payment> external(String reference, {required String key}) =>
      _request(() async {
        final json = await client.post(
          '${_path(reference)}/payments/external',
          token: token,
          headers: _headers(key),
          body: <String, Object>{},
        );
        final result = CheckoutDto.payment(CatalogDto.object(json)['data']);
        if (result.method != PaymentMethod.external) {
          throw const FormatException('Wrong payment method.');
        }
        return result;
      }, externalProvider: true);

  @override
  Future<PaymentPage> payments(String reference, {int page = 1}) =>
      _request(() async {
        if (page < 1 || page > 10000) throw ArgumentError('Invalid page.');
        final json = await client.get(
          '${_path(reference)}/payments',
          token: token,
          queryParameters: {'page': '$page', 'per_page': '$paymentPageSize'},
        );
        final result = CatalogDto.page(
          json,
          CheckoutDto.payment,
          requestedPage: page,
          requestedPerPage: paymentPageSize,
        );
        if (result.items.map((payment) => payment.id).toSet().length !=
            result.items.length) {
          throw const FormatException('Duplicate payment identities.');
        }
        return PaymentPage(
          items: result.items,
          currentPage: result.currentPage,
          lastPage: result.lastPage,
          total: result.total,
        );
      });

  @override
  Future<Payment> reconcile(String reference, int paymentId) =>
      _request(() async {
        CatalogDto.integer(paymentId);
        final json = await client.post(
          '${_path(reference)}/payments/$paymentId/reconcile',
          token: token,
          body: <String, Object>{},
        );
        final result = CheckoutDto.payment(CatalogDto.object(json)['data']);
        if (result.id != paymentId || result.method != PaymentMethod.external) {
          throw const FormatException('Wrong reconciled attempt.');
        }
        return result;
      }, externalProvider: true);

  @override
  Future<Order> cancel(String reference) => _request(() async {
    final json = await client.post(
      '${_path(reference)}/cancel',
      token: token,
      body: <String, Object>{},
    );
    final result = CheckoutDto.order(CatalogDto.object(json)['data']);
    if (result.reference != reference ||
        result.status != OrderStatus.cancelled) {
      throw const FormatException('Invalid cancellation result.');
    }
    return result;
  });

  String _safeMessage(String value) {
    final safe = value
        .replaceAll(token, '[redacted]')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .trim();
    return safe.substring(0, safe.length.clamp(0, 300));
  }

  Future<T> _request<T>(
    Future<T> Function() send, {
    bool externalProvider = false,
  }) async {
    try {
      return await send();
    } on UnauthorizedException {
      throw const CheckoutFailure(CheckoutFailureKind.sessionExpired);
    } on ForbiddenException {
      throw const CheckoutFailure(CheckoutFailureKind.forbidden);
    } on NotFoundException {
      throw const CheckoutFailure(CheckoutFailureKind.notFound);
    } on ConflictException catch (e) {
      throw CheckoutFailure(
        CheckoutFailureKind.conflict,
        detail: _safeMessage(e.message),
      );
    } on ValidationException catch (e) {
      throw CheckoutFailure(
        CheckoutFailureKind.validation,
        errors: Map.unmodifiable({
          for (final entry in e.errors.entries)
            entry.key: List<String>.unmodifiable(entry.value.map(_safeMessage)),
        }),
      );
    } on RateLimitedException catch (e) {
      throw CheckoutFailure(
        CheckoutFailureKind.rateLimited,
        retryAfterSeconds: e.retryAfterSeconds,
      );
    } on ServerException catch (e) {
      throw CheckoutFailure(
        externalProvider && e.statusCode == 503
            ? CheckoutFailureKind.providerUnavailable
            : CheckoutFailureKind.server,
      );
    } on NetworkException {
      throw const CheckoutFailure(CheckoutFailureKind.network);
    } on ApiException {
      throw const CheckoutFailure(CheckoutFailureKind.invalidResponse);
    } on FormatException {
      throw const CheckoutFailure(CheckoutFailureKind.invalidResponse);
    } on ArgumentError {
      throw const CheckoutFailure(CheckoutFailureKind.invalidResponse);
    }
  }
}
