import 'package:coffee_management_mobile/core/network/api_client.dart';
import 'package:coffee_management_mobile/core/network/api_exception.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_api.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_repository.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AuthRepository.login', () {
    test('authenticates with API and writes session to tokenStore', () async {
      final tokenStore = InMemoryAuthTokenStore();
      final mockClient = MockClient((request) async {
        return http.Response('''
          {
            "data": {
              "id": 1,
              "name": "Sokha Ly",
              "email": "sokha@example.test",
              "role": "cashier",
              "permissions": ["process-pos"]
            },
            "token": "tok-123",
            "token_type": "Bearer",
            "expires_at": "2026-10-07T12:00:00Z"
          }
          ''', 200);
      });

      final repo = AuthRepository(
        api: AuthApi(
          client: ApiClient(client: mockClient, baseUrl: 'https://test'),
        ),
        tokenStore: tokenStore,
      );

      final session = await repo.login(
        email: 'sokha@example.test',
        password: 'password',
      );

      expect(session.user.name, equals('Sokha Ly'));
      expect(session.token, equals('tok-123'));
      expect(await tokenStore.readToken(), equals('tok-123'));
    });
  });

  group('AuthRepository.restoreSession', () {
    test('returns null when tokenStore is empty', () async {
      final tokenStore = InMemoryAuthTokenStore();
      var apiCalled = false;

      final mockClient = MockClient((request) async {
        apiCalled = true;
        return http.Response('', 500);
      });

      final repo = AuthRepository(
        api: AuthApi(
          client: ApiClient(client: mockClient, baseUrl: 'https://test'),
        ),
        tokenStore: tokenStore,
      );

      final session = await repo.restoreSession();

      expect(session, isNull);
      expect(apiCalled, isFalse);
    });

    test(
      'clears storage and returns null when stored token is locally expired',
      () async {
        final tokenStore = InMemoryAuthTokenStore();
        await tokenStore.writeSession(
          token: 'expired-token',
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 10),
          ),
        );

        var apiCalled = false;
        final mockClient = MockClient((request) async {
          apiCalled = true;
          return http.Response('', 500);
        });

        final repo = AuthRepository(
          api: AuthApi(
            client: ApiClient(client: mockClient, baseUrl: 'https://test'),
          ),
          tokenStore: tokenStore,
        );

        final session = await repo.restoreSession();

        expect(session, isNull);
        expect(apiCalled, isFalse);
        expect(await tokenStore.readToken(), isNull);
      },
    );

    test(
      'restores session when stored token is valid and /auth/me returns 200',
      () async {
        final tokenStore = InMemoryAuthTokenStore();
        final futureExpiry = DateTime.now().toUtc().add(
          const Duration(hours: 4),
        );
        await tokenStore.writeSession(
          token: 'valid-tok',
          expiresAt: futureExpiry,
        );

        final mockClient = MockClient((request) async {
          expect(request.headers['Authorization'], equals('Bearer valid-tok'));
          return http.Response('''
          {
            "data": {
              "id": 1,
              "name": "Sokha Ly",
              "email": "sokha@example.test",
              "role": "cashier",
              "permissions": ["process-pos"]
            }
          }
          ''', 200);
        });

        final repo = AuthRepository(
          api: AuthApi(
            client: ApiClient(client: mockClient, baseUrl: 'https://test'),
          ),
          tokenStore: tokenStore,
        );

        final session = await repo.restoreSession();

        expect(session, isNotNull);
        expect(session!.user.name, equals('Sokha Ly'));
        expect(session.token, equals('valid-tok'));
      },
    );

    test('clears storage and returns null when /auth/me returns 401', () async {
      final tokenStore = InMemoryAuthTokenStore();
      await tokenStore.writeSession(
        token: 'revoked-tok',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      final mockClient = MockClient((request) async {
        return http.Response('{"message": "Unauthenticated."}', 401);
      });

      final repo = AuthRepository(
        api: AuthApi(
          client: ApiClient(client: mockClient, baseUrl: 'https://test'),
        ),
        tokenStore: tokenStore,
      );

      final session = await repo.restoreSession();

      expect(session, isNull);
      expect(await tokenStore.readToken(), isNull);
    });

    test(
      'clears storage and returns null when /auth/me returns 403 (inactive staff)',
      () async {
        final tokenStore = InMemoryAuthTokenStore();
        await tokenStore.writeSession(
          token: 'deactivated-staff-tok',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );

        final mockClient = MockClient((request) async {
          return http.Response('{"message": "Account inactive."}', 403);
        });

        final repo = AuthRepository(
          api: AuthApi(
            client: ApiClient(client: mockClient, baseUrl: 'https://test'),
          ),
          tokenStore: tokenStore,
        );

        final session = await repo.restoreSession();

        expect(session, isNull);
        expect(await tokenStore.readToken(), isNull);
      },
    );

    test(
      'retains token in storage and rethrows on network failure during restore',
      () async {
        final tokenStore = InMemoryAuthTokenStore();
        final futureExpiry = DateTime.now().toUtc().add(
          const Duration(hours: 2),
        );
        await tokenStore.writeSession(
          token: 'retained-tok',
          expiresAt: futureExpiry,
        );

        final mockClient = MockClient((request) async {
          throw http.ClientException('Socket failed');
        });

        final repo = AuthRepository(
          api: AuthApi(
            client: ApiClient(client: mockClient, baseUrl: 'https://test'),
          ),
          tokenStore: tokenStore,
        );

        expect(() => repo.restoreSession(), throwsA(isA<NetworkException>()));

        // Token must NOT be wiped on temporary network error
        expect(await tokenStore.readToken(), equals('retained-tok'));
      },
    );
  });

  group('AuthRepository.logout', () {
    test('clears tokenStore on 204 success', () async {
      final tokenStore = InMemoryAuthTokenStore();
      await tokenStore.writeSession(
        token: 'to-logout',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      final mockClient = MockClient((request) async {
        return http.Response('', 204);
      });

      final repo = AuthRepository(
        api: AuthApi(
          client: ApiClient(client: mockClient, baseUrl: 'https://test'),
        ),
        tokenStore: tokenStore,
      );

      await repo.logout(token: 'to-logout');
      expect(await tokenStore.readToken(), isNull);
    });

    test('clears tokenStore on 401 already-revoked response', () async {
      final tokenStore = InMemoryAuthTokenStore();
      await tokenStore.writeSession(
        token: 'already-revoked',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      final mockClient = MockClient((request) async {
        return http.Response('{"message": "Unauthenticated"}', 401);
      });

      final repo = AuthRepository(
        api: AuthApi(
          client: ApiClient(client: mockClient, baseUrl: 'https://test'),
        ),
        tokenStore: tokenStore,
      );

      await repo.logout(token: 'already-revoked');
      expect(await tokenStore.readToken(), isNull);
    });
  });
}
