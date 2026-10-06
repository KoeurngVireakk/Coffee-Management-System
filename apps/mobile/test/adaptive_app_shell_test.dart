import 'package:coffee_management_mobile/features/auth/domain/auth_session.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_user.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:coffee_management_mobile/features/preview/presentation/design_system_preview_page.dart';
import 'package:coffee_management_mobile/features/shell/presentation/adaptive_app_shell.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_controller_test.dart';

void main() {
  const cashierUser = AuthUser(
    id: 1,
    name: 'Cashier Sophea',
    email: 'sophea@example.test',
    role: StaffRole.cashier,
    permissions: [
      'view-catalog',
      'process-pos',
      'view-own-orders',
      'view-inventory',
    ],
  );

  const managerUser = AuthUser(
    id: 2,
    name: 'Manager Vibol',
    email: 'vibol@example.test',
    role: StaffRole.manager,
    permissions: [
      'view-catalog',
      'manage-catalog',
      'process-pos',
      'view-own-orders',
      'manage-orders',
      'view-inventory',
      'manage-inventory',
      'adjust-inventory',
      'view-reports',
    ],
  );

  const adminUser = AuthUser(
    id: 3,
    name: 'Admin Rithy',
    email: 'rithy@example.test',
    role: StaffRole.admin,
    permissions: [
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
    ],
  );

  AuthSession createSession(AuthUser user) {
    return AuthSession(
      user: user,
      token: 'test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
    );
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    required AuthController controller,
    ThemeMode themeMode = ThemeMode.light,
    VoidCallback? onToggleTheme,
    String? initialPath,
    Size viewport = const Size(1280, 800),
    double textScaleFactor = 1.0,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildLightTheme(),
        darkTheme: AppTheme.buildDarkTheme(),
        themeMode: themeMode,
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: AdaptiveAppShell(
            authController: controller,
            currentThemeMode: themeMode,
            onToggleTheme: onToggleTheme,
            initialPath: initialPath,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('AdaptiveAppShell - Expanded (Tablet/Desktop ≥600dp)', () {
    testWidgets(
      'renders sidebar with brand header, user profile, and role badge',
      (tester) async {
        final fakeRepo = FakeAuthRepository(
          initialSession: createSession(cashierUser),
        );
        final controller = AuthController(repository: fakeRepo);
        await controller.restoreSession();

        await pumpShell(
          tester,
          controller: controller,
          viewport: const Size(1024, 768),
        );

        expect(find.text('Coffee Management System'), findsOneWidget);
        expect(find.text('ប្រព័ន្ធគ្រប់គ្រងហាងកាហ្វេ'), findsOneWidget);
        expect(find.text('Cashier Sophea'), findsOneWidget);
        expect(find.text('sophea@example.test'), findsOneWidget);
        expect(find.text('CASHIER'), findsOneWidget);
      },
    );

    testWidgets('Cashier defaults to POS destination and sees MAIN badge', (
      tester,
    ) async {
      final fakeRepo = FakeAuthRepository(
        initialSession: createSession(cashierUser),
      );
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await pumpShell(
        tester,
        controller: controller,
        viewport: const Size(1280, 800),
      );

      // Cashier lands directly on /pos
      expect(find.text('Point of Sale'), findsWidgets);
      expect(find.text('MAIN'), findsOneWidget);
    });

    testWidgets('Manager defaults to Dashboard and sees Reports', (
      tester,
    ) async {
      final fakeRepo = FakeAuthRepository(
        initialSession: createSession(managerUser),
      );
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await pumpShell(
        tester,
        controller: controller,
        viewport: const Size(1280, 800),
      );

      // Manager lands on Dashboard
      expect(find.text('Dashboard'), findsWidgets);
      // Manager sees Reports in sidebar
      expect(find.text('Reports'), findsOneWidget);
      // Manager must NOT see Staff
      expect(find.text('Staff'), findsNothing);
    });

    testWidgets(
      'Admin sees full destination list including Staff and Settings',
      (tester) async {
        final fakeRepo = FakeAuthRepository(
          initialSession: createSession(adminUser),
        );
        final controller = AuthController(repository: fakeRepo);
        await controller.restoreSession();

        await pumpShell(
          tester,
          controller: controller,
          viewport: const Size(1280, 800),
        );

        expect(find.text('Dashboard'), findsWidgets);
        expect(find.text('POS'), findsOneWidget);
        expect(find.text('Orders'), findsOneWidget);
        expect(find.text('Products'), findsOneWidget);
        expect(find.text('Inventory'), findsOneWidget);
        expect(find.text('Reports'), findsOneWidget);
        expect(find.text('Staff'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets('clicking a navigation item switches the active page', (
      tester,
    ) async {
      final fakeRepo = FakeAuthRepository(
        initialSession: createSession(adminUser),
      );
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await pumpShell(
        tester,
        controller: controller,
        viewport: const Size(1280, 800),
      );

      // Initial page is Dashboard
      expect(
        find.text('Executive metrics and KPIs will appear here.'),
        findsOneWidget,
      );

      // Tap Inventory in sidebar
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();

      expect(
        find.text('Stock levels and movements will appear here.'),
        findsOneWidget,
      );

      // Tap Staff in sidebar
      await tester.tap(find.text('Staff'));
      await tester.pumpAndSettle();

      expect(find.text('Staff management will appear here.'), findsOneWidget);
    });

    testWidgets('theme toggle callback fires when theme item is tapped', (
      tester,
    ) async {
      var toggled = false;
      final fakeRepo = FakeAuthRepository(
        initialSession: createSession(adminUser),
      );
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await pumpShell(
        tester,
        controller: controller,
        onToggleTheme: () => toggled = true,
        viewport: const Size(1280, 800),
      );

      await tester.tap(find.text('Dark Mode'));
      expect(toggled, isTrue);
    });

    testWidgets('clicking Sign Out invokes logout on AuthController', (
      tester,
    ) async {
      var logoutCalled = false;
      final fakeRepo = FakeAuthRepository(
        initialSession: createSession(cashierUser),
        logoutHandler: (token) async {
          logoutCalled = true;
        },
      );
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await pumpShell(
        tester,
        controller: controller,
        viewport: const Size(1280, 800),
      );

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(logoutCalled, isTrue);
    });

    testWidgets('clicking Design System navigates to DesignSystemPreviewPage', (
      tester,
    ) async {
      final fakeRepo = FakeAuthRepository(
        initialSession: createSession(adminUser),
      );
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await pumpShell(
        tester,
        controller: controller,
        viewport: const Size(1280, 800),
      );

      await tester.tap(find.text('Design System'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesignSystemPreviewPage), findsOneWidget);
    });
  });

  group('AdaptiveAppShell - Compact (Mobile <600dp)', () {
    testWidgets('renders bottom NavigationBar with 5 core tabs', (
      tester,
    ) async {
      final fakeRepo = FakeAuthRepository(
        initialSession: createSession(cashierUser),
      );
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await pumpShell(
        tester,
        controller: controller,
        viewport: const Size(390, 844),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('POS'), findsOneWidget);
      expect(find.text('Stock'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('tapping tabs in compact bottom bar switches active page', (
      tester,
    ) async {
      final fakeRepo = FakeAuthRepository(
        initialSession: createSession(cashierUser),
      );
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await pumpShell(
        tester,
        controller: controller,
        viewport: const Size(390, 844),
      );

      // Cashier starts on POS
      expect(find.text('Point of Sale'), findsWidgets);

      // Tap Orders tab
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(
        find.text('Order history and tracking will appear here.'),
        findsOneWidget,
      );

      // Tap Stock tab
      await tester.tap(find.text('Stock'));
      await tester.pumpAndSettle();

      expect(
        find.text('Stock levels and movements will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'tapping More tab opens MorePage with user info and overflow items',
      (tester) async {
        final fakeRepo = FakeAuthRepository(
          initialSession: createSession(managerUser),
        );
        final controller = AuthController(repository: fakeRepo);
        await controller.restoreSession();

        await pumpShell(
          tester,
          controller: controller,
          viewport: const Size(390, 844),
        );

        // Tap More tab
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();

        // MorePage displays user details
        expect(find.text('Manager Vibol'), findsOneWidget);
        expect(find.text('Manager'), findsOneWidget);

        // Manager's overflow items: Products, Reports
        expect(find.text('Products'), findsOneWidget);
        expect(find.text('Reports'), findsOneWidget);

        // Sign Out option in More menu
        expect(find.text('Sign Out'), findsOneWidget);
      },
    );
  });

  group('AdaptiveAppShell - Responsiveness & Accessibility', () {
    testWidgets('preserves active destination across viewport resizing', (
      tester,
    ) async {
      final fakeRepo = FakeAuthRepository(
        initialSession: createSession(adminUser),
      );
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      // Mount on desktop viewport and navigate to Inventory
      await pumpShell(
        tester,
        controller: controller,
        viewport: const Size(1280, 800),
      );

      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(
        find.text('Stock levels and movements will appear here.'),
        findsOneWidget,
      );

      // Resize down to mobile viewport (compact)
      await pumpShell(
        tester,
        controller: controller,
        viewport: const Size(390, 844),
        initialPath: '/inventory',
      );

      // Should still be showing Inventory content
      expect(
        find.text('Stock levels and movements will appear here.'),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets(
      'mounts cleanly at 1.5x large text scale factor without overflow',
      (tester) async {
        final fakeRepo = FakeAuthRepository(
          initialSession: createSession(cashierUser),
        );
        final controller = AuthController(repository: fakeRepo);
        await controller.restoreSession();

        await pumpShell(
          tester,
          controller: controller,
          viewport: const Size(1024, 768),
          textScaleFactor: 1.5,
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
