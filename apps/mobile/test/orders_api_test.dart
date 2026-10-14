import 'dart:convert';
import 'dart:io';

import 'package:coffee_management_mobile/core/network/api_client.dart';
import 'package:coffee_management_mobile/features/orders/data/api_order_history_repository.dart';
import 'package:coffee_management_mobile/features/orders/domain/order_filter.dart';
import 'package:coffee_management_mobile/features/orders/domain/order_history_repository.dart';
import 'package:coffee_management_mobile/features/pos/data/checkout_dto.dart';
import 'package:coffee_management_mobile/features/pos/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'checkout_test_support.dart';
import 'pos_test_support.dart' as catalog;

void main() {
  ApiOrderHistoryRepository repository(
    Future<http.Response> Function(http.Request) handler, {
    Duration? timeout,
  }) {
    final transport = MockClient(handler);
    addTearDown(transport.close);
    return ApiOrderHistoryRepository(
      client: ApiClient(
        client: transport,
        baseUrl: 'https://api.example.test/api/v1',
        defaultTimeout: timeout ?? const Duration(seconds: 15),
      ),
      token: 'synthetic-bearer-token',
    );
  }

  http.Response response(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Matcher failure(OrderHistoryFailureKind kind) => throwsA(
    isA<OrderHistoryFailure>().having((error) => error.kind, 'kind', kind),
  );

  group('ApiOrderHistoryRepository.orders', () {
    test('sends allowlisted query parameters and bearer token', () async {
      final from = DateTime.utc(2026, 10, 1, 0, 0, 0);
      final to = DateTime.utc(2026, 10, 2, 23, 59, 59);
      final filter = OrderFilter(
        status: OrderStatus.paid,
        createdFrom: from,
        createdTo: to,
      );

      final repo = repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/orders');
        expect(
          request.headers['Authorization'],
          'Bearer synthetic-bearer-token',
        );
        expect(request.url.queryParameters, {
          'status': 'paid',
          'created_from': from.toIso8601String(),
          'created_to': to.toIso8601String(),
          'page': '1',
          'per_page': '1',
        });

        // Ensure no disallowed parameters
        expect(request.url.queryParameters.containsKey('search'), isFalse);
        expect(request.url.queryParameters.containsKey('user_id'), isFalse);

        final page = catalog.pageJson(
          [orderJson(status: 'paid')],
          current: 1,
          size: 1,
          total: 2,
        );
        return response(page);
      });

      final result = await repo.orders(
        status: filter.status,
        createdFrom: filter.createdFrom,
        createdTo: filter.createdTo,
        page: 1,
        perPage: 1,
      );

      expect(result.currentPage, 1);
      expect(result.perPage, 1);
      expect(result.total, 2);
      expect(result.hasMore, isTrue);
      expect(result.items.length, 1);
      expect(result.items.first.status, OrderStatus.paid);
      expect(result.items.first.reference, orderReference);
    });

    test('handles empty results cleanly', () async {
      final repo = repository((request) async {
        expect(request.method, 'GET');
        final page = catalog.pageJson([], current: 1, size: 25, total: 0);
        return response(page);
      });

      final result = await repo.orders();

      expect(result.items, isEmpty);
      expect(result.currentPage, 1);
      expect(result.total, 0);
      expect(result.hasMore, isFalse);
    });
  });

  group('ApiOrderHistoryRepository.order', () {
    test('fetches order by public reference', () async {
      final repo = repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/orders/$orderReference');
        expect(
          request.headers['Authorization'],
          'Bearer synthetic-bearer-token',
        );
        return response({'data': orderJson(status: 'pending_payment')});
      });

      final order = await repo.order(orderReference);
      expect(order.reference, orderReference);
      expect(order.status, OrderStatus.pendingPayment);
    });

    test('validates reference parameter format', () async {
      expect(() => CheckoutDto.reference(''), throwsFormatException);
      expect(() => CheckoutDto.reference('bad-ref'), throwsFormatException);

      final repo = repository((_) async => response({}));
      await expectLater(
        repo.order(''),
        failure(OrderHistoryFailureKind.invalidResponse),
      );
      await expectLater(
        repo.order('bad-ref'),
        failure(OrderHistoryFailureKind.invalidResponse),
      );
    });
  });

  group('ApiOrderHistoryRepository.payments', () {
    test('fetches paginated payments for an order', () async {
      final repo = repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/orders/$orderReference/payments');
        expect(request.url.queryParameters, {'page': '1', 'per_page': '50'});
        final page = catalog.pageJson(
          [paymentJson(id: 1, method: 'cash', status: 'confirmed')],
          current: 1,
          size: 50,
          total: 1,
        );
        return response(page);
      });

      final page = await repo.payments(orderReference, page: 1, perPage: 50);
      expect(page.currentPage, 1);
      expect(page.items.length, 1);
      expect(page.items.first.id, 1);
      expect(page.items.first.status.name, 'confirmed');
    });
  });

  group('ApiOrderHistoryRepository error propagation', () {
    for (final entry in {
      401: OrderHistoryFailureKind.sessionExpired,
      403: OrderHistoryFailureKind.forbidden,
      404: OrderHistoryFailureKind.notFound,
      409: OrderHistoryFailureKind.conflict,
      422: OrderHistoryFailureKind.validation,
      429: OrderHistoryFailureKind.rateLimited,
      500: OrderHistoryFailureKind.server,
    }.entries) {
      test('orders propagates ${entry.key} as ${entry.value}', () async {
        final repo = repository(
          (_) async => response({
            'message': 'Synthetic error message',
            'errors': {
              'status': ['The selected status is invalid.'],
            },
          }, entry.key),
        );

        await expectLater(repo.orders(), failure(entry.value));
      });

      test('order propagates ${entry.key} as ${entry.value}', () async {
        final repo = repository(
          (_) async => response({'message': 'Synthetic error'}, entry.key),
        );

        await expectLater(repo.order(orderReference), failure(entry.value));
      });

      test('payments propagates ${entry.key} as ${entry.value}', () async {
        final repo = repository(
          (_) async => response({'message': 'Synthetic error'}, entry.key),
        );

        await expectLater(repo.payments(orderReference), failure(entry.value));
      });
    }

    test('maps network exceptions to network failure', () async {
      final repo = repository(
        (_) async => throw const SocketException('Network down'),
      );

      await expectLater(
        repo.orders(),
        failure(OrderHistoryFailureKind.network),
      );
    });

    test('maps malformed json response to invalidResponse failure', () async {
      final repo = repository(
        (_) async => http.Response(
          '{"invalid": "structure"}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        repo.orders(),
        failure(OrderHistoryFailureKind.invalidResponse),
      );
    });
  });
}
