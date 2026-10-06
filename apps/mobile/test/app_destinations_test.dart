import 'package:coffee_management_mobile/shared/navigation/app_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDestination permission filtering', () {
    test('Cashier sees only cashier-permitted destinations in expanded view', () {
      final cashierPermissions = [
        'view-catalog',
        'process-pos',
        'view-own-orders',
        'view-inventory',
      ];

      final filtered = filterDestinations(
        expandedDestinations,
        cashierPermissions.contains,
      );

      final paths = filtered.map((d) => d.path).toList();

      // Cashier should see Dashboard (unrestricted), POS, Orders, Products, Inventory
      expect(paths, contains('/dashboard'));
      expect(paths, contains('/pos'));
      expect(paths, contains('/orders'));
      expect(paths, contains('/products'));
      expect(paths, contains('/inventory'));

      // Cashier must NOT see Reports, Staff, or Settings
      expect(paths, isNot(contains('/reports')));
      expect(paths, isNot(contains('/staff')));
      expect(paths, isNot(contains('/settings')));
    });

    test(
      'Manager sees management destinations but NOT staff administration',
      () {
        final managerPermissions = [
          'view-catalog',
          'manage-catalog',
          'process-pos',
          'view-own-orders',
          'manage-orders',
          'view-inventory',
          'manage-inventory',
          'adjust-inventory',
          'view-reports',
        ];

        final filtered = filterDestinations(
          expandedDestinations,
          managerPermissions.contains,
        );

        final paths = filtered.map((d) => d.path).toList();

        expect(paths, contains('/dashboard'));
        expect(paths, contains('/pos'));
        expect(paths, contains('/orders'));
        expect(paths, contains('/products'));
        expect(paths, contains('/inventory'));
        expect(paths, contains('/reports'));

        // Manager must NOT see Staff administration (manage-staff is Admin only)
        expect(paths, isNot(contains('/staff')));
        expect(paths, isNot(contains('/settings')));
      },
    );

    test('Admin sees all expanded destinations', () {
      final adminPermissions = [
        'view-catalog',
        'manage-catalog',
        'process-pos',
        'view-own-orders',
        'manage-orders',
        'view-inventory',
        'manage-inventory',
        'adjust-inventory',
        'manage-staff',
        'manage-settings',
        'view-audit-logs',
        'view-reports',
      ];

      final filtered = filterDestinations(
        expandedDestinations,
        adminPermissions.contains,
      );

      final paths = filtered.map((d) => d.path).toList();

      expect(
        paths,
        equals([
          '/dashboard',
          '/pos',
          '/orders',
          '/products',
          '/inventory',
          '/reports',
          '/staff',
          '/settings',
        ]),
      );
    });

    test('Compact destinations retain 5 core workflow tabs', () {
      final cashierPermissions = [
        'view-catalog',
        'process-pos',
        'view-own-orders',
        'view-inventory',
      ];

      final filtered = filterDestinations(
        compactDestinations,
        cashierPermissions.contains,
      );

      final paths = filtered.map((d) => d.path).toList();

      expect(paths, equals(['/home', '/orders', '/pos', '/stock', '/more']));
    });

    test('User with zero permissions only sees unrestricted destinations', () {
      final filtered = filterDestinations(
        expandedDestinations,
        (perm) => false,
      );

      final paths = filtered.map((d) => d.path).toList();

      // Only destinations with null permission requirement are shown
      expect(paths, equals(['/dashboard']));
    });
  });
}
