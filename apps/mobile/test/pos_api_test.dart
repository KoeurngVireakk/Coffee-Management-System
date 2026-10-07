import 'dart:async';
import 'dart:convert';
import 'package:coffee_management_mobile/core/network/api_client.dart';
import 'package:coffee_management_mobile/features/pos/data/api_catalog_repository.dart';
import 'package:coffee_management_mobile/features/pos/domain/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'pos_test_support.dart';

void main() {
  ApiCatalogRepository repository(
    Future<http.Response> Function(http.Request) handler, {
    Duration? timeout,
  }) {
    final mock = MockClient(handler);
    addTearDown(mock.close);
    return ApiCatalogRepository(
      client: ApiClient(
        client: mock,
        baseUrl: 'https://api.example.test/api/v1',
        defaultTimeout: timeout ?? const Duration(seconds: 15),
      ),
      token: 'synthetic-test-token',
    );
  }

  test(
    'active categories path, bounded query and Bearer authentication',
    () async {
      final repo = repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/categories');
        expect(request.url.queryParameters, {'page': '1', 'per_page': '50'});
        expect(request.headers['Authorization'], 'Bearer synthetic-test-token');
        expect(request.headers['Accept'], 'application/json');
        return http.Response(
          jsonEncode(pageJson([categoryJson()], size: 50)),
          200,
        );
      });
      final result = await repo.categories();
      expect(result.items.single.name, 'Coffee');
      expect(result.hasMore, isFalse);
    },
  );
  test(
    'products encode search safely, filter and paginate without status/sort',
    () async {
      const search = 'កាហ្វេ & + / ? # %_!';
      final repo = repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/products');
        expect(request.url.queryParameters, {
          'page': '2',
          'per_page': '25',
          'category_id': '1',
          'search': search,
        });
        expect(request.headers['Authorization'], 'Bearer synthetic-test-token');
        return http.Response(
          jsonEncode(pageJson([productJson()], current: 2, total: 26)),
          200,
        );
      });
      final result = await repo.products(
        page: 2,
        categoryId: 1,
        search: search,
      );
      expect(result.currentPage, 2);
      expect(result.total, 26);
      expect(result.hasMore, isFalse);
      expect(result.items.single.priceMinor, 325);
    },
  );
  test('empty page is valid', () async {
    final repo = repository(
      (_) async => http.Response(jsonEncode(pageJson([])), 200),
    );
    expect((await repo.products()).items, isEmpty);
  });
  for (final entry in {
    401: CatalogFailureKind.sessionExpired,
    403: CatalogFailureKind.forbidden,
    422: CatalogFailureKind.validation,
    429: CatalogFailureKind.rateLimited,
    500: CatalogFailureKind.server,
    503: CatalogFailureKind.server,
  }.entries) {
    test(
      'maps ${entry.key} to controlled ${entry.value} failure on both endpoints',
      () async {
        final repo = repository(
          (_) async => http.Response(
            '{"message":"synthetic internal detail"}',
            entry.key,
          ),
        );
        for (final request in [repo.products(), repo.categories()]) {
          await expectLater(
            request,
            throwsA(
              isA<CatalogFailure>().having(
                (failure) => failure.kind,
                'kind',
                entry.value,
              ),
            ),
          );
        }
      },
    );
  }
  test('network exception is actionable without transport details', () async {
    final repo = repository(
      (_) async => throw http.ClientException('sensitive transport detail'),
    );
    await expectLater(
      repo.products(),
      throwsA(
        isA<CatalogFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              CatalogFailureKind.network,
            )
            .having(
              (failure) => failure.message,
              'message',
              isNot(contains('sensitive')),
            ),
      ),
    );
  });
  test('timeout becomes network failure', () async {
    final pending = Completer<http.Response>();
    final repo = repository(
      (_) => pending.future,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      repo.products(),
      throwsA(
        isA<CatalogFailure>().having(
          (failure) => failure.kind,
          'kind',
          CatalogFailureKind.network,
        ),
      ),
    );
    pending.complete(http.Response('{}', 200));
  });
  for (final body in ['not json', 'null', '[]', '{}', '{"data":[]}']) {
    test('reject incomplete JSON envelope $body', () async {
      final repo = repository((_) async => http.Response(body, 200));
      await expectLater(
        repo.products(),
        throwsA(
          isA<CatalogFailure>().having(
            (failure) => failure.kind,
            'kind',
            CatalogFailureKind.invalidResponse,
          ),
        ),
      );
    });
  }
  for (final mutation in <void Function(Map<String, dynamic>)>[
    (json) => json['data'] = {},
    (json) => json['meta']['current_page'] = '1',
    (json) => json['meta']['current_page'] = 2,
    (json) => json['meta']['per_page'] = 101,
    (json) => json['meta']['last_page'] = 0,
    (json) => json['meta']['total'] = -1,
    (json) => json['meta']['from'] = 2,
    (json) => json['meta']['from'] = 1.0,
    (json) => json['meta'].remove('from'),
    (json) => json['meta']['to'] = null,
    (json) => json['links']['next'] = 'not a URL',
    (json) => json['links']['next'] = 'https://example.test?page=2',
    (json) => json['data'][0]['price_minor'] = '03',
    (json) => json['data'][0]['category'] = [],
    (json) {
      json['data'][0]['is_active'] = false;
      json['data'][0]['is_sellable'] = false;
    },
  ]) {
    test(
      'invalid catalog response ${mutation.toString()} fails closed',
      () async {
        final json = pageJson([productJson()]);
        mutation(json);
        final repo = repository(
          (_) async => http.Response(jsonEncode(json), 200),
        );
        await expectLater(
          repo.products(),
          throwsA(
            isA<CatalogFailure>().having(
              (failure) => failure.kind,
              'kind',
              CatalogFailureKind.invalidResponse,
            ),
          ),
        );
      },
    );
  }
  test('duplicate IDs within a page fail closed', () async {
    final repo = repository(
      (_) async => http.Response(
        jsonEncode(pageJson([productJson(), productJson()])),
        200,
      ),
    );
    await expectLater(repo.products(), throwsA(isA<CatalogFailure>()));
  });
  test('inactive categories rejected in normal POS response', () async {
    final repo = repository(
      (_) async => http.Response(
        jsonEncode(
          pageJson([
            {...categoryJson(), 'is_active': false},
          ], size: 50),
        ),
        200,
      ),
    );
    await expectLater(repo.categories(), throwsA(isA<CatalogFailure>()));
  });
  test('invalid query bounds rejected before HTTP', () async {
    final repo = repository((_) async => fail('Must not perform HTTP'));
    for (final request in [
      repo.products(page: 10001),
      repo.categories(page: 0),
      repo.products(categoryId: 0),
      repo.products(search: 'a' * 81),
    ]) {
      await expectLater(
        request,
        throwsA(
          isA<CatalogFailure>().having(
            (failure) => failure.kind,
            'kind',
            CatalogFailureKind.validation,
          ),
        ),
      );
    }
  });
}
