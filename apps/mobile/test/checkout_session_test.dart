import 'dart:async';
import 'package:coffee_management_mobile/app.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_session.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_user.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:coffee_management_mobile/features/pos/domain/checkout_repository.dart';
import 'package:coffee_management_mobile/features/pos/domain/payment.dart';
import 'package:coffee_management_mobile/features/pos/presentation/checkout_controller.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_controller_test.dart';
import 'checkout_test_support.dart';
import 'pos_test_support.dart';

void main() {
  Future<AuthController> auth() async {
    const user = AuthUser(
      id: 1,
      name: 'Synthetic cashier',
      email: 'cashier@example.test',
      role: StaffRole.cashier,
      permissions: ['view-catalog', 'process-pos', 'view-own-orders'],
    );
    final controller = AuthController(
      repository: FakeAuthRepository(
        initialSession: AuthSession(
          user: user,
          token: 'synthetic-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
        ),
      ),
    );
    await controller.restoreSession();
    return controller;
  }

  Future<CheckoutController> mount(
    WidgetTester tester,
    AuthController auth,
    FakeCheckoutRepository repository,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CoffeeManagementApp(
        authController: auth,
        catalogRepository: FakeCatalogRepository(),
        checkoutRepository: repository,
      ),
    );
    await tester.pump();
    final pos = tester.widget<PosPage>(find.byType(PosPage)).controller;
    pos.add(product());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-cart')));
    await tester.pumpAndSettle();
    return pos.checkout!;
  }

  testWidgets(
    'financial 401 invalidates session and dismisses active transaction sheet',
    (tester) async {
      final session = await auth();
      addTearDown(session.dispose);
      final repository = FakeCheckoutRepository();
      final checkout = await mount(tester, session, repository);
      repository.onCreate = (_) async =>
          throw const CheckoutFailure(CheckoutFailureKind.sessionExpired);
      await checkout.checkout();
      await tester.pumpAndSettle();
      expect(session.state, isA<Unauthenticated>());
      expect(find.text('Staff Sign In'), findsOneWidget);
      expect(find.text('Pending Order'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('financial 403 preserves authenticated session, order and cart', (
    tester,
  ) async {
    final session = await auth();
    addTearDown(session.dispose);
    final repository = FakeCheckoutRepository();
    final checkout = await mount(tester, session, repository);
    await checkout.checkout();
    repository.onCash = (_, _, _) async =>
        throw const CheckoutFailure(CheckoutFailureKind.forbidden);
    await checkout.cash(1000);
    await tester.pumpAndSettle();
    expect(session.isAuthenticated, isTrue);
    expect(checkout.state.order!.reference, orderReference);
    expect(checkout.cart.itemCount, 1);
    expect(find.textContaining('do not have permission'), findsOneWidget);
    expect(find.text('Staff Sign In'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late cash response after sign-out cannot reopen paid UI', (
    tester,
  ) async {
    final session = await auth();
    addTearDown(session.dispose);
    final repository = FakeCheckoutRepository();
    final checkout = await mount(tester, session, repository);
    await checkout.checkout();
    final pending = Completer<Payment>();
    repository.onCash = (_, _, _) => pending.future;
    final payment = checkout.cash(1000);
    await session.logout();
    await tester.pumpAndSettle();
    pending.complete(paymentFixture());
    await payment;
    await tester.pump();
    expect(find.text('Staff Sign In'), findsOneWidget);
    expect(find.text('Payment successful'), findsNothing);
    expect(repository.orderReads.length, 1);
    expect(tester.takeException(), isNull);
  });
}
