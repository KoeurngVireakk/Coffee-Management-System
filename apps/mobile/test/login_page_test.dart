import 'dart:async';

import 'package:coffee_management_mobile/core/network/api_exception.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_session.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_user.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:coffee_management_mobile/features/auth/presentation/login_page.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:coffee_management_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_controller_test.dart';

void main() {
  const sampleUser = AuthUser(
    id: 1,
    name: 'Cashier Dara',
    email: 'dara@example.test',
    role: StaffRole.cashier,
    permissions: ['process-pos'],
  );

  final sampleSession = AuthSession(
    user: sampleUser,
    token: 'tok-abc',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
  );

  Widget buildLoginPage({required AuthController controller}) {
    return MaterialApp(
      theme: AppTheme.buildLightTheme(),
      home: LoginPage(authController: controller),
    );
  }

  group('LoginPage UI & Form UX', () {
    testWidgets(
      'renders brand title, Khmer subtitle, inputs, and submit button',
      (tester) async {
        final fakeRepo = FakeAuthRepository();
        final controller = AuthController(repository: fakeRepo);

        await tester.pumpWidget(buildLoginPage(controller: controller));

        expect(find.text('Coffee Management System'), findsOneWidget);
        expect(find.text('ប្រព័ន្ធគ្រប់គ្រងហាងកាហ្វេ'), findsOneWidget);
        expect(find.text('Staff Sign In'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
      },
    );

    testWidgets('validates local empty fields before submission', (
      tester,
    ) async {
      var loginCalled = false;
      final fakeRepo = FakeAuthRepository(
        loginHandler: (email, password) async {
          loginCalled = true;
          return sampleSession;
        },
      );
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(buildLoginPage(controller: controller));

      // Tap Sign In with empty fields
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(loginCalled, isFalse);
      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('validates invalid email format', (tester) async {
      var loginCalled = false;
      final fakeRepo = FakeAuthRepository(
        loginHandler: (email, password) async {
          loginCalled = true;
          return sampleSession;
        },
      );
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(buildLoginPage(controller: controller));

      await tester.enterText(find.byType(TextField).first, 'invalidemail');
      await tester.enterText(find.byType(TextField).last, 'validpassword');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(loginCalled, isFalse);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(buildLoginPage(controller: controller));

      final passwordFieldFinder = find.byType(TextField).last;
      TextField passwordField = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordField.obscureText, isTrue);

      // Tap visibility toggle icon button
      final toggleFinder = find.byTooltip('Show password');
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pump();

      passwordField = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordField.obscureText, isFalse);
    });

    testWidgets(
      'submits form with valid credentials and clears password on success',
      (tester) async {
        String? sentEmail;
        String? sentPassword;

        final fakeRepo = FakeAuthRepository(
          loginHandler: (email, password) async {
            sentEmail = email;
            sentPassword = password;
            return sampleSession;
          },
        );
        final controller = AuthController(repository: fakeRepo);

        await tester.pumpWidget(buildLoginPage(controller: controller));

        await tester.enterText(
          find.byType(TextField).first,
          'dara@example.test',
        );
        await tester.enterText(find.byType(TextField).last, 'secret123');
        await tester.tap(find.text('Sign In'));
        await tester.pump();

        expect(sentEmail, equals('dara@example.test'));
        expect(sentPassword, equals('secret123'));

        // Password input should be cleared
        final passwordField = tester.widget<TextField>(
          find.byType(TextField).last,
        );
        expect(passwordField.controller?.text, isEmpty);
      },
    );

    testWidgets('displays server error banner on 401 invalid credentials', (
      tester,
    ) async {
      final fakeRepo = FakeAuthRepository(
        loginHandler: (email, password) async {
          throw const UnauthorizedException(
            'The provided credentials are incorrect.',
          );
        },
      );
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(buildLoginPage(controller: controller));

      await tester.enterText(find.byType(TextField).first, 'dara@example.test');
      await tester.enterText(find.byType(TextField).last, 'wrong');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(
        find.text(
          'The provided credentials are incorrect, or this account cannot sign in.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('loading state disables sign-in button', (tester) async {
      final completer = Completer<AuthSession>();
      final fakeRepo = FakeAuthRepository(
        loginHandler: (email, password) => completer.future,
      );
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(buildLoginPage(controller: controller));

      await tester.enterText(find.byType(TextField).first, 'dara@example.test');
      await tester.enterText(find.byType(TextField).last, 'password');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      // Submit button should have isLoading true
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);

      completer.complete(sampleSession);
      await tester.pump();
    });
  });

  group('LoginPage responsive viewports', () {
    testWidgets('renders cleanly on mobile viewport (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(buildLoginPage(controller: controller));
      await tester.pump();

      expect(find.text('Staff Sign In'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on tablet viewport (768x1024)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(buildLoginPage(controller: controller));
      await tester.pump();

      expect(find.text('Staff Sign In'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on POS desktop viewport (1280x800)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(buildLoginPage(controller: controller));
      await tester.pump();

      expect(find.text('Staff Sign In'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
