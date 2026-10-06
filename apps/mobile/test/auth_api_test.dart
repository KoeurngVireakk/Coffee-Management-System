import 'dart:convert';

import 'package:coffee_management_mobile/core/network/api_client.dart';
import 'package:coffee_management_mobile/core/network/api_exception.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_api.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AuthApi.login', () {
    test(
      'sends exact normalized body and parses successful response',
      () async {
        late Map<String, dynamic> sentBody;

        final mockClient = MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;

          return http.Response(
            jsonEncode({
              'data': {
                'id': 1,
                'name': 'Barista Sreymom',
                'email': 'sreymom@example.test',
                'role': 'cashier',
                'permissions': ['view-catalog', 'process-pos'],
              },
              'token': 'plain-text-token-12345',
              'token_type': 'Bearer',
              'expires_at': '2026-10-07T08:00:00.000000Z',
            }),
            200,
          );
        });

        final apiClient = ApiClient(
          client: mockClient,
          baseUrl: 'https://api.test/api/v1',
        );
        final authApi = AuthApi(
          client: apiClient,
          deviceName: 'Coffee POS Android',
        );

        final result = await authApi.login(
          email: ' Sreymom@Example.Test  ',
          password: ' PasswordWithSpaces#1 ',
        );

        // Verify email was normalized to trimmed lowercase
        expect(sentBody['email'], equals('sreymom@example.test'));
        // Verify password was NOT trimmed or modified
        expect(sentBody['password'], equals(' PasswordWithSpaces#1 '));
        // Verify device_name matches
        expect(sentBody['device_name'], equals('Coffee POS Android'));

        expect(result.user.name, equals('Barista Sreymom'));
        expect(result.user.role, equals(StaffRole.cashier));
        expect(result.token, equals('plain-text-token-12345'));
        expect(result.expiresAt, equals(DateTime.utc(2026, 10, 7, 8, 0)));
      },
    );

    test(
      'throws InvalidResponseException if token_type is not Bearer',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 1,
                'name': 'Staff',
                'email': 's@ex.test',
                'role': 'cashier',
                'permissions': [],
              },
              'token': 'token-123',
              'token_type': 'Basic',
              'expires_at': '2026-10-07T08:00:00Z',
            }),
            200,
          );
        });

        final apiClient = ApiClient(
          client: mockClient,
          baseUrl: 'https://api.test/api/v1',
        );
        final authApi = AuthApi(client: apiClient);

        expect(
          () => authApi.login(email: 's@ex.test', password: 'pwd'),
          throwsA(isA<InvalidResponseException>()),
        );
      },
    );
  });

  group('AuthApi.getMe', () {
    test(
      'sends Authorization header and parses UserResource envelope',
      () async {
        late String? authHeader;

        final mockClient = MockClient((request) async {
          authHeader = request.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'data': {
                'id': 5,
                'name': 'Manager Kosal',
                'email': 'kosal@example.test',
                'role': 'manager',
                'permissions': ['manage-catalog', 'view-reports'],
              },
            }),
            200,
          );
        });

        final apiClient = ApiClient(
          client: mockClient,
          baseUrl: 'https://api.test/api/v1',
        );
        final authApi = AuthApi(client: apiClient);

        final user = await authApi.getMe(token: 'live-bearer-token');

        expect(authHeader, equals('Bearer live-bearer-token'));
        expect(user.id, equals(5));
        expect(user.role, equals(StaffRole.manager));
        expect(user.hasPermission('manage-catalog'), isTrue);
      },
    );
  });

  group('AuthApi.logout', () {
    test('sends Bearer token to /auth/logout and completes on 204', () async {
      late String? authHeader;

      final mockClient = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        expect(request.url.path, endsWith('/auth/logout'));
        return http.Response('', 204);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.test/api/v1',
      );
      final authApi = AuthApi(client: apiClient);

      await authApi.logout(token: 'active-token-to-revoke');
      expect(authHeader, equals('Bearer active-token-to-revoke'));
    });
  });
}
