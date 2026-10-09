import 'dart:async';
import 'dart:convert';
import 'package:coffee_management_mobile/core/network/api_client.dart';
import 'package:coffee_management_mobile/features/pos/data/api_checkout_repository.dart';
import 'package:coffee_management_mobile/features/pos/domain/checkout_intent.dart';
import 'package:coffee_management_mobile/features/pos/domain/checkout_repository.dart';
import 'package:coffee_management_mobile/features/pos/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'checkout_test_support.dart';
import 'pos_test_support.dart' as catalog;

void main() {
  ApiCheckoutRepository repository(
    Future<http.Response> Function(http.Request) handler, {
    Duration? timeout,
  }) {
    final transport = MockClient(handler);
    addTearDown(transport.close);
    return ApiCheckoutRepository(
      client: ApiClient(
        client: transport,
        baseUrl: 'https://api.example.test/api/v1',
        defaultTimeout: timeout ?? const Duration(seconds: 15),
      ),
      token: 'synthetic-bearer-token',
    );
  }

  CheckoutIntent intent() => CheckoutIntent(
    key: 'checkout-test-key',
    items: [CheckoutItem(productId: 1, quantity: 1)],
    previewTotalMinor: 325,
  );
  http.Response response(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  Matcher failure(CheckoutFailureKind kind) => throwsA(
    isA<CheckoutFailure>().having((error) => error.kind, 'kind', kind),
  );

  for (final status in [201, 200]) {
    test(
      'checkout $status sends only exact intent and its own key, server price wins',
      () async {
        final repo = repository((request) async {
          expect(request.url.path, '/api/v1/orders');
          expect(request.method, 'POST');
          expect(
            request.headers['Authorization'],
            'Bearer synthetic-bearer-token',
          );
          expect(request.headers['Idempotency-Key'], 'checkout-test-key');
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {
            'items': [
              {'product_id': 1, 'quantity': 1},
            ],
          });
          return response({'data': orderJson(unit: 450)}, status);
        });
        expect((await repo.createOrder(intent())).totalMinor, 450);
      },
    );
    test(
      'cash $status sends canonical string tender and stable payment key',
      () async {
        final repo = repository((request) async {
          expect(
            request.url.path,
            '/api/v1/orders/$orderReference/payments/cash',
          );
          expect(request.headers['Idempotency-Key'], 'cash-test-key');
          expect(
            request.headers['Authorization'],
            'Bearer synthetic-bearer-token',
          );
          expect(jsonDecode(request.body), {'tender_minor': '1000'});
          return response({'data': paymentJson()}, status);
        });
        final payment = await repo.cash(
          orderReference,
          key: 'cash-test-key',
          tenderMinor: 1000,
        );
        expect(payment.changeMinor, 675);
      },
    );
  }
  for (final status in [
    'initiated',
    'pending',
    'uncertain',
    'failed',
    'expired',
    'confirmed',
  ]) {
    test(
      'external $status sends empty object and parses backend state',
      () async {
        final repo = repository((request) async {
          expect(
            request.url.path,
            '/api/v1/orders/$orderReference/payments/external',
          );
          expect(request.method, 'POST');
          expect(request.headers['Idempotency-Key'], 'external-test-key');
          expect(jsonDecode(request.body), <String, Object>{});
          return response({
            'data': paymentJson(
              method: 'external',
              status: status,
              payload: status == 'pending' ? 'SYNTHETIC-QR' : null,
            ),
          }, 201);
        });
        final payment = await repo.external(
          orderReference,
          key: 'external-test-key',
        );
        expect(payment.status.name, status);
        expect(payment.qrPayload, status == 'pending' ? 'SYNTHETIC-QR' : null);
      },
    );
  }
  test(
    'reconcile scopes order and payment, empty body and no client proof/key',
    () async {
      final repo = repository((request) async {
        expect(
          request.url.path,
          '/api/v1/orders/$orderReference/payments/7/reconcile',
        );
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), <String, Object>{});
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
        return response({
          'data': paymentJson(id: 7, method: 'external', review: true),
        });
      });
      expect(
        (await repo.reconcile(orderReference, 7)).reconciliationRequired,
        isTrue,
      );
    },
  );
  test(
    'cancel sends only empty object and accepts persisted cancelled state',
    () async {
      final repo = repository((request) async {
        expect(request.url.path, '/api/v1/orders/$orderReference/cancel');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), <String, Object>{});
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
        return response({'data': orderJson(status: 'cancelled')});
      });
      expect((await repo.cancel(orderReference)).status, OrderStatus.cancelled);
    },
  );
  test(
    'active payment list uses bounded metadata and ignores server URLs for requests',
    () async {
      final repo = repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/orders/$orderReference/payments');
        expect(request.url.queryParameters, {'page': '2', 'per_page': '100'});
        final page = catalog.pageJson(
          [paymentJson()],
          current: 2,
          size: 100,
          total: 101,
        );
        page['links']['first'] = 'https://untrusted.example.test';
        return response(page);
      });
      final page = await repo.payments(orderReference, page: 2);
      expect(page.currentPage, 2);
      expect(page.total, 101);
      expect(page.hasMore, isFalse);
    },
  );
  for (final status in ['pending_payment', 'paid', 'cancelled', 'expired']) {
    test('GET active order returns persisted $status', () async {
      final repo = repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/orders/$orderReference');
        expect(
          request.headers['Authorization'],
          'Bearer synthetic-bearer-token',
        );
        return response({'data': orderJson(status: status)});
      });
      expect((await repo.order(orderReference)).reference, orderReference);
    });
  }
  for (final entry in {
    401: CheckoutFailureKind.sessionExpired,
    403: CheckoutFailureKind.forbidden,
    404: CheckoutFailureKind.notFound,
    409: CheckoutFailureKind.conflict,
    422: CheckoutFailureKind.validation,
    429: CheckoutFailureKind.rateLimited,
    500: CheckoutFailureKind.server,
  }.entries) {
    for (final operation in [
      'checkout',
      'cash',
      'external',
      'reconcile',
      'cancel',
      'order',
      'payments',
    ]) {
      test('$operation propagates ${entry.key} as ${entry.value}', () async {
        final repo = repository(
          (_) async => response({
            'message': 'Synthetic controlled conflict',
            'errors': {
              'tender_minor': ['Tender is too small.'],
            },
          }, entry.key),
        );
        final request = switch (operation) {
          'checkout' => repo.createOrder(intent()),
          'cash' => repo.cash(
            orderReference,
            key: 'cash-test-key',
            tenderMinor: 1000,
          ),
          'external' => repo.external(orderReference, key: 'external-test-key'),
          'reconcile' => repo.reconcile(orderReference, 1),
          'cancel' => repo.cancel(orderReference),
          'order' => repo.order(orderReference),
          _ => repo.payments(orderReference),
        };
        await expectLater(request, failure(entry.value));
      });
    }
  }
  test(
    '503 means provider unavailable only for external provider operations',
    () async {
      final repo = repository(
        (_) async => response({'message': 'Unconfigured'}, 503),
      );
      await expectLater(
        repo.external(orderReference, key: 'external-test-key'),
        failure(CheckoutFailureKind.providerUnavailable),
      );
      await expectLater(
        repo.reconcile(orderReference, 1),
        failure(CheckoutFailureKind.providerUnavailable),
      );
      await expectLater(
        repo.cash(orderReference, key: 'cash-test-key', tenderMinor: 1000),
        failure(CheckoutFailureKind.server),
      );
      await expectLater(
        repo.createOrder(intent()),
        failure(CheckoutFailureKind.server),
      );
    },
  );
  test('429 preserves Retry-After and 422 preserves field errors', () async {
    final repo = repository(
      (_) async => http.Response(
        '{"message":"slow down"}',
        429,
        headers: {'retry-after': '12'},
      ),
    );
    await expectLater(
      repo.external(orderReference, key: 'external-test-key'),
      throwsA(
        isA<CheckoutFailure>().having(
          (error) => error.retryAfterSeconds,
          'retry-after',
          12,
        ),
      ),
    );
    final invalid = repository(
      (_) async => response({
        'errors': {
          'tender_minor': ['Cash must cover the order.'],
        },
      }, 422),
    );
    await expectLater(
      invalid.cash(orderReference, key: 'cash-test-key', tenderMinor: 1000),
      throwsA(
        isA<CheckoutFailure>().having(
          (error) => error.fieldMessage('tender_minor'),
          'field',
          'Cash must cover the order.',
        ),
      ),
    );
  });
  test(
    'conflict text is bounded, control-cleaned and token-redacted',
    () async {
      final repo = repository(
        (_) async =>
            response({'message': 'synthetic-bearer-token\n${'a' * 400}'}, 409),
      );
      await expectLater(
        repo.createOrder(intent()),
        throwsA(
          isA<CheckoutFailure>()
              .having(
                (error) => error.message,
                'redaction',
                isNot(contains('synthetic-bearer-token')),
              )
              .having(
                (error) => error.message.length,
                'bounded message',
                lessThanOrEqualTo(300),
              ),
        ),
      );
    },
  );
  test('transport error and timeout are controlled unknown outcomes', () async {
    final repo = repository(
      (_) async => throw http.ClientException('Synthetic transport detail'),
    );
    await expectLater(
      repo.createOrder(intent()),
      failure(CheckoutFailureKind.network),
    );
    final pending = Completer<http.Response>();
    final slow = repository(
      (_) => pending.future,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      slow.cash(orderReference, key: 'cash-test-key', tenderMinor: 1000),
      failure(CheckoutFailureKind.network),
    );
    pending.complete(response({'data': paymentJson()}));
  });
  test(
    'successful transport with malformed data is never financial success',
    () async {
      for (final value in [
        'not-json',
        'null',
        '{}',
        '{"data":{"status":"paid"}}',
      ]) {
        final repo = repository((_) async => http.Response(value, 200));
        await expectLater(
          repo.createOrder(intent()),
          failure(CheckoutFailureKind.invalidResponse),
        );
      }
    },
  );
  test('wrong response identities, method and intent fail closed', () async {
    final wrongOrder = repository(
      (_) async => response({
        'data': {
          ...orderJson(),
          'public_reference': 'ORD-01K6WY00000000000000000001',
        },
      }),
    );
    await expectLater(
      wrongOrder.order(orderReference),
      failure(CheckoutFailureKind.invalidResponse),
    );
    final wrongIntent = repository(
      (_) async => response({
        'data': orderJson(
          intentItems: [CheckoutItem(productId: 2, quantity: 1)],
        ),
      }),
    );
    await expectLater(
      wrongIntent.createOrder(intent()),
      failure(CheckoutFailureKind.invalidResponse),
    );
    final wrongPayment = repository(
      (_) async => response({'data': paymentJson(id: 2, method: 'external')}),
    );
    await expectLater(
      wrongPayment.reconcile(orderReference, 1),
      failure(CheckoutFailureKind.invalidResponse),
    );
    await expectLater(
      wrongPayment.cash(
        orderReference,
        key: 'cash-test-key',
        tenderMinor: 1000,
      ),
      failure(CheckoutFailureKind.invalidResponse),
    );
  });
}
