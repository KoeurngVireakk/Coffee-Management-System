import 'dart:async';
import 'package:coffee_management_mobile/app.dart';
import 'package:coffee_management_mobile/core/network/api_client.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_api.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_repository.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_token_store.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_session.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_user.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:coffee_management_mobile/features/pos/domain/catalog_repository.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_page.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_product_card.dart';
import 'package:coffee_management_mobile/features/shell/presentation/adaptive_app_shell.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'auth_controller_test.dart';
import 'pos_test_support.dart';

const cashier = AuthUser(
  id: 1,
  name: 'Synthetic cashier',
  email: 'cashier@example.test',
  role: StaffRole.cashier,
  permissions: ['process-pos', 'view-catalog'],
);
AuthSession session({
  String token = 'synthetic-token',
  AuthUser user = cashier,
}) => AuthSession(
  user: user,
  token: token,
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
);

class DelayedCleanupRepository extends FakeAuthRepository {
  DelayedCleanupRepository()
    : super(
        initialSession: session(),
        loginHandler: (_, _) async => session(token: 'new-token'),
      );
  final cleanup = Completer<void>();
  int loginCalls = 0;
  @override
  Future<void> clearInvalidSession() => cleanup.future;
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    return super.login(email: email, password: password);
  }
}

void main() {
  test(
    '401 invalidation clears real repository token storage without an HTTP mutation',
    () async {
      final store = InMemoryAuthTokenStore();
      final current = session();
      await store.writeSession(
        token: current.token,
        expiresAt: current.expiresAt,
      );
      final transport = MockClient(
        (_) async => fail('Invalidation must not POST logout'),
      );
      addTearDown(transport.close);
      final repository = AuthRepository(
        api: AuthApi(
          client: ApiClient(
            client: transport,
            baseUrl: 'https://api.example.test/api/v1',
          ),
        ),
        tokenStore: store,
      );
      await repository.clearInvalidSession();
      expect(await store.readToken(), isNull);
      expect(await store.readExpiresAt(), isNull);
    },
  );
  test('session invalidation is scoped to requesting token', () async {
    final repository = FakeAuthRepository(initialSession: session());
    final auth = AuthController(repository: repository);
    addTearDown(auth.dispose);
    await auth.restoreSession();
    await auth.invalidateSession(token: 'old-token');
    expect(auth.isAuthenticated, isTrue);
    expect(repository.invalidSessionClears, 0);
    await auth.invalidateSession(token: 'synthetic-token');
    expect(auth.state, isA<Unauthenticated>());
    expect(repository.invalidSessionClears, 1);
  });
  test('new login waits for pending old-session storage cleanup', () async {
    final repository = DelayedCleanupRepository();
    final auth = AuthController(repository: repository);
    addTearDown(auth.dispose);
    await auth.restoreSession();
    final invalidation = auth.invalidateSession(token: 'synthetic-token');
    expect(auth.state, isA<Unauthenticated>());
    final login = auth.login('synthetic@example.test', 'synthetic-password');
    await Future<void>.delayed(Duration.zero);
    expect(repository.loginCalls, 0);
    repository.cleanup.complete();
    await invalidation;
    expect(await login, isTrue);
    expect((auth.state as Authenticated).session.token, 'new-token');
  });
  testWidgets('401 returns to login and dismisses open cart sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final authRepository = FakeAuthRepository(initialSession: session());
    final auth = AuthController(repository: authRepository);
    addTearDown(auth.dispose);
    await auth.restoreSession();
    final catalog = FakeCatalogRepository();
    await tester.pumpWidget(
      CoffeeManagementApp(authController: auth, catalogRepository: catalog),
    );
    await tester.pump();
    final pos = tester.widget<PosPage>(find.byType(PosPage)).controller;
    await tester.tap(find.byType(PosProductCard));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-cart')));
    await tester.pumpAndSettle();
    catalog.onProducts = (_, _, _) async =>
        throw const CatalogFailure(CatalogFailureKind.sessionExpired);
    await pos.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Staff Sign In'), findsOneWidget);
    expect(find.text('Current Order'), findsNothing);
    expect(authRepository.invalidSessionClears, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('403 leaves authenticated shell and existing cart intact', (
    tester,
  ) async {
    final auth = AuthController(
      repository: FakeAuthRepository(initialSession: session()),
    );
    addTearDown(auth.dispose);
    await auth.restoreSession();
    final catalog = FakeCatalogRepository();
    await tester.pumpWidget(
      CoffeeManagementApp(authController: auth, catalogRepository: catalog),
    );
    await tester.pump();
    final pos = tester.widget<PosPage>(find.byType(PosPage)).controller;
    pos.add(product());
    catalog.onProducts = (_, _, _) async =>
        throw const CatalogFailure(CatalogFailureKind.forbidden);
    await pos.refresh();
    await tester.pump();
    expect(auth.isAuthenticated, isTrue);
    expect(pos.cart.subtotalMinor, 325);
    expect(find.textContaining('do not have access'), findsOneWidget);
    expect(find.text('Staff Sign In'), findsNothing);
  });
  testWidgets(
    'actual shell preserves cart through navigation, resize and theme',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = AuthController(
        repository: FakeAuthRepository(initialSession: session()),
      );
      addTearDown(auth.dispose);
      await auth.restoreSession();
      final catalog = FakeCatalogRepository();
      await tester.pumpWidget(
        CoffeeManagementApp(authController: auth, catalogRepository: catalog),
      );
      await tester.pump();
      await tester.tap(find.byType(PosProductCard));
      await tester.pump();
      await tester.tap(find.text('Dashboard'));
      await tester.pump();
      await tester.tap(find.text('POS').first);
      await tester.pump();
      final pos = tester.widget<PosPage>(find.byType(PosPage)).controller;
      expect(pos.cart.itemCount, 1);
      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      tester.view.physicalSize = const Size(375, 812);
      await tester.pumpAndSettle();
      expect(find.text('View cart · 1 items'), findsOneWidget);
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(find.text('Current Order'), findsOneWidget);
      expect(catalog.productRequests.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'direct POS destination without process-pos is denied before catalog requests',
    (tester) async {
      const user = AuthUser(
        id: 2,
        name: 'Restricted staff',
        email: 'staff@example.test',
        role: StaffRole.manager,
        permissions: ['view-catalog'],
      );
      final auth = AuthController(
        repository: FakeAuthRepository(initialSession: session(user: user)),
      );
      addTearDown(auth.dispose);
      await auth.restoreSession();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: AdaptiveAppShell(
            authController: auth,
            posController: null,
            initialPath: '/pos',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('POS access denied'), findsOneWidget);
      expect(find.byType(PosPage), findsNothing);
    },
  );
}
