import 'package:coffee_management_mobile/app.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_session.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_user.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_controller_test.dart';

void main() {
  testWidgets('application shell boots to LoginPage when unauthenticated', (
    tester,
  ) async {
    final fakeRepo = FakeAuthRepository(initialSession: null);
    final controller = AuthController(repository: fakeRepo);
    await controller.restoreSession();

    await tester.pumpWidget(CoffeeManagementApp(authController: controller));
    await tester.pump();

    expect(find.text('Coffee Management System'), findsOneWidget);
    expect(find.text('Staff Sign In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'application shell boots to AuthenticatedPlaceholderPage when session restored',
    (tester) async {
      const user = AuthUser(
        id: 1,
        name: 'Barista Sreymom',
        email: 'sreymom@example.test',
        role: StaffRole.cashier,
        permissions: ['process-pos'],
      );
      final session = AuthSession(
        user: user,
        token: 'tok-abc',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 4)),
      );

      final fakeRepo = FakeAuthRepository(initialSession: session);
      final controller = AuthController(repository: fakeRepo);
      await controller.restoreSession();

      await tester.pumpWidget(CoffeeManagementApp(authController: controller));
      await tester.pump();

      expect(find.text('Coffee Management System'), findsOneWidget);
      expect(find.text('Barista Sreymom'), findsOneWidget);
      expect(find.text('CASHIER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
