import 'package:coffee_management_mobile/core/network/api_exception.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_api.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_repository.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_token_store.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_failure.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_session.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_user.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake repository for fine-grained controller testing without HTTP serialization.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.initialSession,
    this.loginHandler,
    this.logoutHandler,
  });

  AuthSession? initialSession;
  Future<AuthSession> Function(String email, String password)? loginHandler;
  Future<void> Function(String token)? logoutHandler;

  @override
  AuthApi get api => throw UnimplementedError();

  @override
  AuthTokenStore get tokenStore => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() async {
    return initialSession;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (loginHandler != null) {
      return loginHandler!(email, password);
    }
    throw const UnauthorizedException();
  }

  @override
  Future<void> logout({required String token}) async {
    if (logoutHandler != null) {
      return logoutHandler!(token);
    }
  }

  int invalidSessionClears = 0;
  @override
  Future<void> clearInvalidSession() async {
    invalidSessionClears++;
  }
}

void main() {
  const sampleUser = AuthUser(
    id: 1,
    name: 'Cashier Chan',
    email: 'chan@example.test',
    role: StaffRole.cashier,
    permissions: ['process-pos'],
  );

  final sampleSession = AuthSession(
    user: sampleUser,
    token: 'valid-test-token',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
  );

  group('AuthController.restoreSession', () {
    test(
      'transitions to Authenticated when repository finds valid session',
      () async {
        final fakeRepo = FakeAuthRepository(initialSession: sampleSession);
        final controller = AuthController(repository: fakeRepo);

        expect(controller.state, isA<AuthInitializing>());

        await controller.restoreSession();

        expect(controller.state, isA<Authenticated>());
        final authState = controller.state as Authenticated;
        expect(authState.user.name, equals('Cashier Chan'));
      },
    );

    test(
      'transitions to Unauthenticated when repository finds no session',
      () async {
        final fakeRepo = FakeAuthRepository(initialSession: null);
        final controller = AuthController(repository: fakeRepo);

        await controller.restoreSession();

        expect(controller.state, isA<Unauthenticated>());
        expect((controller.state as Unauthenticated).failure, isNull);
      },
    );
  });

  group('AuthController.login', () {
    test(
      'transitions to Authenticating then Authenticated on success',
      () async {
        final fakeRepo = FakeAuthRepository(
          loginHandler: (email, password) async {
            return sampleSession;
          },
        );
        final controller = AuthController(repository: fakeRepo);

        final states = <Type>[];
        controller.addListener(() {
          states.add(controller.state.runtimeType);
        });

        final success = await controller.login('chan@example.test', 'password');

        expect(success, isTrue);
        expect(states, containsAllInOrder([Authenticating, Authenticated]));
      },
    );

    test(
      'transitions to Unauthenticated with InvalidCredentialsFailure on 401',
      () async {
        final fakeRepo = FakeAuthRepository(
          loginHandler: (email, password) async {
            throw const UnauthorizedException();
          },
        );
        final controller = AuthController(repository: fakeRepo);

        final success = await controller.login('bad@example.test', 'wrong');

        expect(success, isFalse);
        expect(controller.state, isA<Unauthenticated>());
        final failure = (controller.state as Unauthenticated).failure;
        expect(failure, isA<InvalidCredentialsFailure>());
      },
    );

    test(
      'transitions to Unauthenticated with InactiveStaffFailure on 403',
      () async {
        final fakeRepo = FakeAuthRepository(
          loginHandler: (email, password) async {
            throw const ForbiddenException();
          },
        );
        final controller = AuthController(repository: fakeRepo);

        final success = await controller.login('inactive@example.test', 'pwd');

        expect(success, isFalse);
        final failure = (controller.state as Unauthenticated).failure;
        expect(failure, isA<InactiveStaffFailure>());
      },
    );

    test(
      'transitions to Unauthenticated with ValidationFailure on 422',
      () async {
        final fakeRepo = FakeAuthRepository(
          loginHandler: (email, password) async {
            throw const ValidationException(
              'The given data was invalid.',
              errors: {
                'email': ['The email must be a valid email address.'],
              },
            );
          },
        );
        final controller = AuthController(repository: fakeRepo);

        final success = await controller.login('invalid-email', 'pwd');

        expect(success, isFalse);
        final failure = (controller.state as Unauthenticated).failure;
        expect(failure, isA<ValidationFailure>());
        expect(
          (failure as ValidationFailure).firstErrorFor('email'),
          contains('valid email'),
        );
      },
    );

    test('prevents concurrent duplicate submissions', () async {
      var callCount = 0;
      final fakeRepo = FakeAuthRepository(
        loginHandler: (email, password) async {
          callCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return sampleSession;
        },
      );
      final controller = AuthController(repository: fakeRepo);

      final f1 = controller.login('a@b.c', 'p');
      final f2 = controller.login('a@b.c', 'p'); // concurrent call

      final results = await Future.wait([f1, f2]);

      expect(callCount, equals(1));
      expect(results, equals([true, false]));
    });
  });

  group('AuthController.logout', () {
    test('transitions from Authenticated to Unauthenticated', () async {
      final fakeRepo = FakeAuthRepository(initialSession: sampleSession);
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      expect(controller.isAuthenticated, isTrue);

      final success = await controller.logout();

      expect(success, isTrue);
      expect(controller.state, isA<Unauthenticated>());
    });

    test(
      'rethrows NetworkException and preserves session on server revocation failure',
      () async {
        final fakeRepo = FakeAuthRepository(
          initialSession: sampleSession,
          logoutHandler: (token) async {
            throw const NetworkException('Connection reset');
          },
        );
        final controller = AuthController(repository: fakeRepo);
        await controller.restoreSession();

        expect(controller.isAuthenticated, isTrue);

        expect(() => controller.logout(), throwsA(isA<NetworkException>()));
        // State should remain Authenticated so user can retry
        expect(controller.isAuthenticated, isTrue);
      },
    );
  });
}
