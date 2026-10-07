import 'dart:async';
import 'package:coffee_management_mobile/features/pos/domain/catalog.dart';
import 'package:coffee_management_mobile/features/pos/domain/catalog_repository.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_controller.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_page.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_product_card.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pos_test_support.dart';

void main() {
  late FakeCatalogRepository repository;
  late PosController controller;
  setUp(() {
    repository = FakeCatalogRepository();
    controller = PosController(repository: repository);
  });
  tearDown(() => controller.dispose());
  Future<void> pumpPos(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.buildDarkTheme() : AppTheme.buildLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: Scaffold(body: PosPage(controller: controller)),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openCart(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('open-cart')));
    await tester.pumpAndSettle();
  }

  testWidgets('initial loading is explicit and empty cart is reachable', (
    tester,
  ) async {
    final pending = Completer<CatalogPage<CatalogProduct>>();
    repository.onProducts = (_, _, _) => pending.future;
    await pumpPos(tester);
    expect(find.text('Loading catalog…'), findsOneWidget);
    expect(find.text('View cart · 0 items'), findsOneWidget);
    pending.complete(page([product()]));
    await tester.pump();
    await openCart(tester);
    expect(find.text('Your order is empty'), findsOneWidget);
    expect(find.text('Current Order'), findsOneWidget);
  });
  testWidgets(
    'mobile product selection, exact subtotal, quantities, remove and clear',
    (tester) async {
      await pumpPos(tester);
      await tester.tap(find.byType(PosProductCard));
      await tester.pump();
      await tester.tap(find.byType(PosProductCard));
      await tester.pump();
      expect(find.text('View cart · 2 items'), findsOneWidget);
      expect(find.text(r'$6.50 USD'), findsOneWidget);
      await openCart(tester);
      await tester.tap(find.byTooltip('Increase Cappuccino quantity'));
      await tester.pump();
      expect(controller.cart.itemCount, 3);
      await tester.tap(find.byTooltip('Decrease Cappuccino quantity'));
      await tester.pump();
      expect(controller.cart.itemCount, 2);
      await tester.tap(find.byTooltip('Remove Cappuccino'));
      await tester.pump();
      expect(find.text('Your order is empty'), findsOneWidget);
      controller.add(product());
      await tester.pump();
      await tester.tap(find.text('Clear cart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep order'));
      await tester.pumpAndSettle();
      expect(controller.cart.itemCount, 1);
      await tester.tap(find.text('Clear cart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear order'));
      await tester.pumpAndSettle();
      expect(controller.cart.itemCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'search debounce, selected categories and empty search have separate states',
    (tester) async {
      await pumpPos(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Coffee'));
      await tester.pump();
      expect(controller.categoryId, 1);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Coffee'))
            .selected,
        isTrue,
      );
      repository.onProducts = (_, _, _) async => page([]);
      await tester.enterText(find.byType(TextField), 'no match');
      await tester.pump(const Duration(milliseconds: 299));
      expect(repository.productRequests.length, 2);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('No search results'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.enterText(find.byType(TextField), 'x' * 81);
      expect(repository.productRequests.last.search, 'no match');
    },
  );
  testWidgets('network error and retry retain cart', (tester) async {
    controller.add(product());
    repository.onProducts = (_, _, _) async =>
        throw const CatalogFailure(CatalogFailureKind.network);
    await pumpPos(tester);
    expect(find.textContaining('Cannot reach the catalog'), findsOneWidget);
    expect(find.text(r'$3.25 USD'), findsOneWidget);
    repository.onProducts = null;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(PosProductCard), findsOneWidget);
    expect(controller.cart.itemCount, 1);
  });
  for (final kind in [
    CatalogFailureKind.forbidden,
    CatalogFailureKind.server,
    CatalogFailureKind.invalidResponse,
  ]) {
    testWidgets('$kind displays its actionable message', (tester) async {
      repository.onProducts = (_, _, _) async => throw CatalogFailure(kind);
      await pumpPos(tester);
      expect(find.text(CatalogFailure(kind).message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'quantity limit feedback is accessible and never increments past 99',
    (tester) async {
      for (var i = 0; i < 99; i++) {
        controller.add(product());
      }
      await pumpPos(tester);
      await openCart(tester);
      expect(find.text('99-item limit reached'), findsOneWidget);
      await tester.tap(find.byTooltip('Increase Cappuccino quantity'));
      await tester.pump();
      expect(find.textContaining('at most 99 items'), findsOneWidget);
      expect(controller.cart.itemCount, 99);
    },
  );
  testWidgets('51st product shows clear line limit feedback', (tester) async {
    for (var id = 1; id <= 50; id++) {
      controller.add(product(id: id));
    }
    repository.onProducts = (_, _, _) async =>
        page([product(id: 51, name: 'New tea')]);
    await pumpPos(tester);
    await tester.tap(find.byType(PosProductCard));
    await tester.pump();
    expect(
      find.textContaining('at most 50 different products'),
      findsOneWidget,
    );
    expect(controller.cart.distinctCount, 50);
  });
  testWidgets(
    'empty categories and empty catalog are distinct from network errors',
    (tester) async {
      repository.onCategories = (_) async => page([]);
      repository.onProducts = (_, _, _) async => page([]);
      await pumpPos(tester);
      expect(find.text('No active categories'), findsOneWidget);
      expect(find.text('No products available'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );
  testWidgets('empty selected category has specific copy', (tester) async {
    await pumpPos(tester);
    repository.onProducts = (_, _, _) async => page([]);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Coffee'));
    await tester.pump();
    expect(find.text('No products in this category'), findsOneWidget);
  });
  testWidgets(
    'load-more error preserves cards and retry fetches the same next page',
    (tester) async {
      repository.onProducts = (_, _, _) async =>
          page([product()], last: 2, total: 2);
      await pumpPos(tester, size: const Size(1440, 900));
      repository.onProducts = (_, _, _) async =>
          throw const CatalogFailure(CatalogFailureKind.network);
      await tester.tap(find.text('Load more products'));
      await tester.pump();
      expect(find.byType(PosProductCard), findsOneWidget);
      expect(find.text('Showing previously loaded products.'), findsOneWidget);
      repository.onProducts = (_, _, _) async =>
          page([product(id: 2)], current: 2, last: 2);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(PosProductCard), findsNWidgets(2));
      expect(repository.productRequests.map((request) => request.page), [
        1,
        2,
        2,
      ]);
      expect(find.text('Load more products'), findsNothing);
    },
  );
  testWidgets(
    'desktop has a persistent panel and resize/theme changes preserve cart',
    (tester) async {
      await pumpPos(tester, size: const Size(1440, 900));
      expect(find.text('Current Order'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-cart')), findsNothing);
      await tester.tap(find.byType(PosProductCard));
      await tester.pump();
      expect(find.text(r'$3.25'), findsWidgets);
      await pumpPos(tester, size: const Size(390, 844), dark: true);
      expect(find.text('View cart · 1 items'), findsOneWidget);
      expect(repository.productRequests.length, 1);
      await openCart(tester);
      expect(find.byTooltip('Increase Cappuccino quantity'), findsOneWidget);
      expect(controller.cart.subtotalMinor, 325);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(320, 720),
    const Size(375, 812),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1440, 900),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'no overflow $size ${dark ? 'dark' : 'light'} at 2x text with Khmer names',
        (tester) async {
          repository.onProducts = (_, _, _) async => page([
            product(
              name: 'កាហ្វេទឹកដោះគោ · Long Cambodian coffee product name',
            ),
          ]);
          controller.add(
            product(
              name: 'កាហ្វេទឹកដោះគោ · Long Cambodian coffee product name',
            ),
          );
          await pumpPos(tester, size: size, dark: dark, scale: 2);
          expect(tester.takeException(), isNull);
          if (find.byKey(const ValueKey('open-cart')).evaluate().isNotEmpty) {
            await openCart(tester);
          }
          expect(find.text('Current Order'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('product semantics, labeled controls and touch targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPos(tester);
    expect(
      find.bySemanticsLabel(RegExp('Add Cappuccino,.*USD')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Search products by name or SKU'),
      findsOneWidget,
    );
    await tester.tap(find.byType(PosProductCard));
    await tester.pump();
    await openCart(tester);
    expect(
      tester
          .getSemantics(find.byTooltip('Increase Cappuccino quantity'))
          .getSemanticsData()
          .tooltip,
      'Increase Cappuccino quantity',
    );
    for (final tooltip in [
      'Increase Cappuccino quantity',
      'Decrease Cappuccino quantity',
      'Remove Cappuccino',
      'Close cart',
    ]) {
      final size = tester.getSize(find.byTooltip(tooltip));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    semantics.dispose();
  });
  testWidgets('keyboard can activate a product without a pointer', (
    tester,
  ) async {
    await pumpPos(tester, size: const Size(1440, 900));
    // Walk the same Tab order used by staff; Enter activates the focused card.
    for (var i = 0; i < 20 && controller.cart.itemCount == 0; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      var onProduct = false;
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
        element,
      ) {
        if (element.widget is PosProductCard) onProduct = true;
        return true;
      });
      if (onProduct) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      }
    }
    expect(controller.cart.itemCount, 1);
  });
}
