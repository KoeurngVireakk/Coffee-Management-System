import 'package:coffee_management_mobile/features/auth/domain/auth_session.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_user.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:coffee_management_mobile/features/auth/presentation/authenticated_placeholder_page.dart';
import 'package:coffee_management_mobile/features/preview/presentation/design_system_preview_page.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_controller_test.dart';

void main() {
  const sampleUser = AuthUser(
    id: 99,
    name: 'Admin Vicheka',
    email: 'vicheka@example.test',
    role: StaffRole.admin,
    permissions: ['manage-staff', 'manage-catalog', 'view-reports'],
  );

  final sampleSession = AuthSession(
    user: sampleUser,
    token: 'super-secret-plain-text-token-never-display',
    expiresAt: DateTime.utc(2026, 10, 7, 18, 0),
  );

  testWidgets(
    'AuthenticatedPlaceholderPage displays staff details and redacts token',
    (tester) async {
      final fakeRepo = FakeAuthRepository(initialSession: sampleSession);
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: AuthenticatedPlaceholderPage(
            session: sampleSession,
            authController: controller,
          ),
        ),
      );

      expect(find.text('Admin Vicheka'), findsOneWidget);
      expect(find.text('vicheka@example.test'), findsOneWidget);
      expect(find.text('ADMINISTRATOR'), findsOneWidget);
      expect(find.text('#99'), findsOneWidget);
      expect(find.text('manage-staff'), findsOneWidget);
      expect(find.text('manage-catalog'), findsOneWidget);
      expect(find.text('view-reports'), findsOneWidget);

      // CRITICAL SECURITY INVARIANT: The raw token must NEVER be visible in the UI
      expect(
        find.text('super-secret-plain-text-token-never-display'),
        findsNothing,
      );
    },
  );

  testWidgets('clicking Sign Out button invokes logout', (tester) async {
    var logoutCalled = false;
    final fakeRepo = FakeAuthRepository(
      initialSession: sampleSession,
      logoutHandler: (token) async {
        logoutCalled = true;
      },
    );
    final controller = AuthController(repository: fakeRepo);
    await controller.restoreSession();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildLightTheme(),
        home: AuthenticatedPlaceholderPage(
          session: sampleSession,
          authController: controller,
        ),
      ),
    );

    final signOutBtn = find.text('Sign Out');
    expect(signOutBtn, findsOneWidget);

    await tester.tap(signOutBtn);
    await tester.pump();

    expect(logoutCalled, isTrue);
  });

  testWidgets('navigates to DesignSystemPreviewPage on preview button tap', (
    tester,
  ) async {
    final fakeRepo = FakeAuthRepository(initialSession: sampleSession);
    final controller = AuthController(repository: fakeRepo);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildLightTheme(),
        home: AuthenticatedPlaceholderPage(
          session: sampleSession,
          authController: controller,
        ),
      ),
    );

    final previewBtn = find.text('View Design System Preview');
    expect(previewBtn, findsOneWidget);

    await tester.tap(previewBtn);
    await tester.pump(); // Start transition
    await tester.pump(const Duration(milliseconds: 300)); // Finish transition

    expect(find.byType(DesignSystemPreviewPage), findsOneWidget);
  });
}
