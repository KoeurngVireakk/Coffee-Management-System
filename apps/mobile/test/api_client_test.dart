import 'dart:convert';

import 'package:coffee_management_mobile/core/network/api_client.dart';
import 'package:coffee_management_mobile/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiClient URL handling', () {
    test('normalizes trailing slashes on base URL', () {
      final client = ApiClient(
        client: http.Client(),
        baseUrl: 'http://localhost:8000/api/v1///',
      );
      expect(client.baseUrl, equals('http://localhost:8000/api/v1'));
    });

    test('rejects empty or malformed base URL', () {
      expect(
        () => ApiClient(client: http.Client(), baseUrl: ''),
        throwsArgumentError,
      );
      expect(
        () => ApiClient(client: http.Client(), baseUrl: 'not-a-valid-uri'),
        throwsArgumentError,
      );
    });
  });

  group('ApiClient HTTP requests & header composition', () {
    test('attaches Accept and Authorization headers on GET', () async {
      late http.Request capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.example.test/api/v1',
      );

      final result = await apiClient.get('/test', token: 'my-test-token');

      expect(
        capturedRequest.url.toString(),
        equals('https://api.example.test/api/v1/test'),
      );
      expect(capturedRequest.headers['Accept'], equals('application/json'));
      expect(
        capturedRequest.headers['Authorization'],
        equals('Bearer my-test-token'),
      );
      expect(result, equals({'status': 'ok'}));
    });

    test('attaches Content-Type and encodes body on POST', () async {
      late http.Request capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'data': 'created'}), 201);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.example.test/api/v1',
      );

      final result = await apiClient.post(
        '/items',
        body: {'name': 'Latte', 'price': 350},
        token: 'auth-token-123',
      );

      expect(
        capturedRequest.headers['Content-Type'],
        equals('application/json'),
      );
      expect(
        capturedRequest.headers['Authorization'],
        equals('Bearer auth-token-123'),
      );
      expect(capturedRequest.body, equals('{"name":"Latte","price":350}'));
      expect(result, equals({'data': 'created'}));
    });

    test('handles 204 No Content returning null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 204);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.example.test/api/v1',
      );

      final result = await apiClient.post('/auth/logout', token: 'valid-token');
      expect(result, isNull);
    });
  });

  group('ApiClient error mapping', () {
    test('maps 401 to UnauthorizedException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'The provided credentials are incorrect.'}),
          401,
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.test',
      );

      expect(
        () => apiClient.post('/auth/login', body: {'email': 'a@b.c'}),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'The provided credentials are incorrect.',
          ),
        ),
      );
    });

    test('maps 403 to ForbiddenException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'This action is unauthorized.'}),
          403,
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.test',
      );

      expect(
        () => apiClient.get('/admin-only', token: 'cashier-token'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('maps 404 to NotFoundException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Not found'}), 404);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.test',
      );

      expect(
        () => apiClient.get('/missing'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('maps 409 to ConflictException with code', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Cannot deactivate last operational admin.',
            'code': 'LAST_ADMIN_PROTECTED',
          }),
          409,
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.test',
      );

      expect(
        () => apiClient.post('/staff/1/deactivate'),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.code,
            'code',
            'LAST_ADMIN_PROTECTED',
          ),
        ),
      );
    });

    test('maps 422 to ValidationException with parsed field errors', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'The given data was invalid.',
            'errors': {
              'email': ['The email field is required.'],
              'device_name': ['This field is not allowed.'],
            },
          }),
          422,
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.test',
      );

      expect(
        () => apiClient.post('/auth/login', body: {}),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['email'],
            'email error',
            contains('The email field is required.'),
          ),
        ),
      );
    });

    test('maps 429 to RateLimitedException with Retry-After header', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Too Many Attempts.'}),
          429,
          headers: {'retry-after': '60'},
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.test',
      );

      expect(
        () => apiClient.post('/auth/login'),
        throwsA(
          isA<RateLimitedException>().having(
            (e) => e.retryAfterSeconds,
            'retryAfterSeconds',
            60,
          ),
        ),
      );
    });

    test('maps 500 to ServerException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.test',
      );

      expect(() => apiClient.get('/error'), throwsA(isA<ServerException>()));
    });

    test('maps non-JSON 200 to InvalidResponseException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html><body>Not JSON</body></html>', 200);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.test',
      );

      expect(
        () => apiClient.get('/html'),
        throwsA(isA<InvalidResponseException>()),
      );
    });
  });
}
