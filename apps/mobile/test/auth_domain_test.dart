import 'package:coffee_management_mobile/features/auth/domain/auth_failure.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_session.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_user.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StaffRole', () {
    test('parses known roles case-insensitively', () {
      expect(StaffRole.fromString('cashier'), equals(StaffRole.cashier));
      expect(StaffRole.fromString('CASHIER'), equals(StaffRole.cashier));
      expect(StaffRole.fromString('manager'), equals(StaffRole.manager));
      expect(StaffRole.fromString('Manager '), equals(StaffRole.manager));
      expect(StaffRole.fromString('admin'), equals(StaffRole.admin));
      expect(StaffRole.fromString('ADMIN'), equals(StaffRole.admin));
    });

    test('fails closed on unknown or invalid role string', () {
      expect(
        () => StaffRole.fromString('superadmin'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => StaffRole.fromString('guest'),
        throwsA(isA<FormatException>()),
      );
      expect(() => StaffRole.fromString(''), throwsA(isA<FormatException>()));
    });

    test('role helper flags are mutually exclusive', () {
      expect(StaffRole.cashier.isCashier, isTrue);
      expect(StaffRole.cashier.isManager, isFalse);
      expect(StaffRole.cashier.isAdmin, isFalse);

      expect(StaffRole.manager.isManager, isTrue);
      expect(StaffRole.admin.isAdmin, isTrue);
    });
  });

  group('AuthUser', () {
    test('parses valid UserResource JSON with permissions', () {
      final json = {
        'id': 42,
        'name': 'Dara Sok',
        'email': 'dara@example.test',
        'role': 'cashier',
        'permissions': ['view-catalog', 'process-pos'],
        'extra_field_future': 'harmless_ignore',
      };

      final user = AuthUser.fromJson(json);

      expect(user.id, equals(42));
      expect(user.name, equals('Dara Sok'));
      expect(user.email, equals('dara@example.test'));
      expect(user.role, equals(StaffRole.cashier));
      expect(user.permissions, equals(['view-catalog', 'process-pos']));
      expect(user.hasPermission('process-pos'), isTrue);
      expect(user.hasPermission('manage-staff'), isFalse);
    });

    test('throws FormatException on missing or invalid fields', () {
      expect(
        () => AuthUser.fromJson({
          'name': 'No ID',
          'email': 'a@b.c',
          'role': 'cashier',
          'permissions': [],
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => AuthUser.fromJson({
          'id': 1,
          'name': 'No Role',
          'email': 'a@b.c',
          'permissions': [],
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => AuthUser.fromJson({
          'id': 1,
          'name': 'No Perms',
          'email': 'a@b.c',
          'role': 'admin',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('serializes to JSON correctly', () {
      const user = AuthUser(
        id: 1,
        name: 'Admin User',
        email: 'admin@example.test',
        role: StaffRole.admin,
        permissions: ['manage-staff'],
      );

      final json = user.toJson();
      expect(json['id'], equals(1));
      expect(json['role'], equals('admin'));
      expect(json['permissions'], equals(['manage-staff']));
    });
  });

  group('AuthSession', () {
    const testUser = AuthUser(
      id: 1,
      name: 'Test Staff',
      email: 'staff@example.test',
      role: StaffRole.manager,
      permissions: ['view-inventory'],
    );

    test('identifies expired and non-expired sessions', () {
      final activeSession = AuthSession(
        user: testUser,
        token: 'plain-text-token-abc',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      expect(activeSession.isExpired, isFalse);
      expect(activeSession.timeRemaining.inMinutes, greaterThan(0));

      final expiredSession = AuthSession(
        user: testUser,
        token: 'plain-text-token-abc',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );

      expect(expiredSession.isExpired, isTrue);
    });

    test('toString redacts the bearer token to prevent log leakage', () {
      final session = AuthSession(
        user: testUser,
        token: 'secret-sanctum-bearer-token-12345',
        expiresAt: DateTime.utc(2026, 10, 7, 12, 0),
      );

      final stringOutput = session.toString();
      expect(stringOutput, contains('[REDACTED]'));
      expect(
        stringOutput,
        isNot(contains('secret-sanctum-bearer-token-12345')),
      );
    });
  });

  group('AuthFailure', () {
    test('ValidationFailure exposes field error mapping', () {
      const failure = ValidationFailure(
        userMessage: 'Validation failed',
        errors: {
          'email': ['The email field is required.'],
          'password': ['Password is too short.'],
        },
      );

      expect(
        failure.firstErrorFor('email'),
        equals('The email field is required.'),
      );
      expect(
        failure.firstErrorFor('password'),
        equals('Password is too short.'),
      );
      expect(failure.firstErrorFor('device_name'), isNull);
    });
  });
}
