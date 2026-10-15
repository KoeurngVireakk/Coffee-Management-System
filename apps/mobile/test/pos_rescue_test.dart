import 'package:coffee_management_mobile/features/pos/domain/catalog_repository.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_category_art.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_controller.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_page.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_product_card.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'checkout_test_support.dart';
import 'pos_test_support.dart';

void main() {
  setUpAll(() async {
    for (final font in <String, String>{
      'Inter': 'inter/Inter.ttf',
      'Noto Sans Khmer': 'notosanskhmer/NotoSansKhmer.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
  });
  late FakeCatalogRepository repository;
  late PosController controller;
  setUp(() {
    repository = FakeCatalogRepository();
    controller = PosController(repository: repository);
  });
  tearDown(() => controller.dispose());

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    bool reduced = false,
    bool accessible = false,
    double keyboard = 0,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.buildDarkTheme() : AppTheme.buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
            accessibleNavigation: accessible,
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Luna Cafe')),
          bottomNavigationBar: const SizedBox(height: 80),
          body: PosPage(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'local category motifs differ without inventing imagery for unknown labels',
    () {
      expect(posCategoryIcon('Coffee'), Icons.coffee_outlined);
      expect(posCategoryIcon('Tea'), Icons.emoji_food_beverage_outlined);
      expect(posCategoryIcon('Bakery'), Icons.bakery_dining_outlined);
      expect(
        posCategoryIcon('Unrecognized Khmer category'),
        Icons.restaurant_menu_outlined,
      );
    },
  );

  testWidgets(
    'identical outages show one notice; one retry recovers both streams and retains cart',
    (tester) async {
      controller.add(product());
      repository.onCategories = (_) async =>
          throw const CatalogFailure(CatalogFailureKind.network);
      repository.onProducts = (_, _, _) async =>
          throw const CatalogFailure(CatalogFailureKind.network);
      await pump(tester);
      expect(
        find.text(const CatalogFailure(CatalogFailureKind.network).message),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      repository.onCategories = null;
      repository.onProducts = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.categoryRequests, [1, 1]);
      expect(repository.productRequests.map((r) => r.page), [1, 1]);
      expect(find.byType(PosProductCard), findsOneWidget);
      expect(controller.cart.subtotalMinor, 325);
    },
  );

  testWidgets('distinct failures retain separate messages and recovery paths', (
    tester,
  ) async {
    repository.onCategories = (_) async =>
        throw const CatalogFailure(CatalogFailureKind.network);
    repository.onProducts = (_, _, _) async =>
        throw const CatalogFailure(CatalogFailureKind.forbidden);
    await pump(tester);
    expect(
      find.text(const CatalogFailure(CatalogFailureKind.network).message),
      findsOneWidget,
    );
    expect(
      find.text(const CatalogFailure(CatalogFailureKind.forbidden).message),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNWidgets(2));
    repository.onCategories = null;
    await tester.tap(find.text('Retry').first);
    await tester.pumpAndSettle();
    expect(repository.categoryRequests.length, 2);
    expect(repository.productRequests.length, 1);
    expect(
      find.text(const CatalogFailure(CatalogFailureKind.forbidden).message),
      findsOneWidget,
    );
  });

  testWidgets(
    'combined next-page failures retry both exact pages without discarding previous rows',
    (tester) async {
      repository.onCategories = (_) async =>
          page([category()], last: 2, total: 2);
      repository.onProducts = (_, _, _) async =>
          page([product()], last: 2, total: 2);
      await pump(tester);
      repository.onCategories = (_) async =>
          throw const CatalogFailure(CatalogFailureKind.network);
      repository.onProducts = (_, _, _) async =>
          throw const CatalogFailure(CatalogFailureKind.network);
      await controller.loadMoreCategories();
      await controller.loadMoreProducts();
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Showing previously loaded products.'), findsOneWidget);
      repository.onCategories = (_) async =>
          page([category(id: 2, name: 'Tea')], current: 2, last: 2, total: 2);
      repository.onProducts = (_, _, _) async =>
          page([product(id: 2)], current: 2, last: 2, total: 2);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.categoryRequests, [1, 2, 2]);
      expect(repository.productRequests.map((r) => r.page), [1, 2, 2]);
      expect(controller.products.items.map((p) => p.id), [1, 2]);
      expect(controller.categories.items.map((c) => c.id), [1, 2]);
    },
  );

  testWidgets(
    '390px initial view shows two full product rows above the allocated cart action',
    (tester) async {
      repository.onProducts = (_, _, _) async =>
          page([for (var i = 1; i <= 8; i++) product(id: i)]);
      await pump(tester);
      final cards = find.byType(PosProductCard);
      expect(tester.getRect(cards.first).top, lessThanOrEqualTo(280));
      final summary = tester.getRect(find.byKey(const ValueKey('open-cart')));
      expect(tester.getRect(cards.at(3)).bottom, lessThan(summary.top));
      expect(summary.height, greaterThanOrEqualTo(56));
      expect(summary.height, lessThanOrEqualTo(64));
      for (final chip in tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      )) {
        expect(
          tester.getSize(find.byWidget(chip)).height,
          greaterThanOrEqualTo(48),
        );
      }
      for (final button in tester.widgetList<IconButton>(
        find.byType(IconButton),
      )) {
        expect(
          tester.getSize(find.byWidget(button)).shortestSide,
          greaterThanOrEqualTo(48),
        );
      }
    },
  );

  testWidgets(
    '744px tablet allocation has persistent draft cart, resize preserves identity/data with no fetch',
    (tester) async {
      await pump(tester, size: const Size(744, 768));
      expect(find.text('Current Order'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-cart')), findsNothing);
      await tester.tap(find.byType(PosProductCard));
      await tester.pumpAndSettle();
      expect(controller.cart.subtotalMinor, 325);
      await pump(tester, size: const Size(390, 844), scale: 2);
      expect(find.text('View cart · 1 item'), findsOneWidget);
      expect(repository.productRequests.length, 1);
      expect(repository.categoryRequests.length, 1);
      await tester.tap(find.byKey(const ValueKey('open-cart')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Increase Cappuccino quantity'), findsOneWidget);
    },
  );

  for (final preferences in [
    (reduced: false, accessible: false),
    (reduced: true, accessible: false),
    (reduced: false, accessible: true),
  ]) {
    testWidgets(
      'count feedback honors $preferences and authoritative money updates immediately',
      (tester) async {
        controller.add(product());
        await pump(
          tester,
          reduced: preferences.reduced,
          accessible: preferences.accessible,
        );
        await tester.tap(find.byType(PosProductCard));
        await tester.pump();
        expect(controller.cart.itemCount, 2);
        expect(find.text(r'$6.50 USD'), findsOneWidget);
        final switcher = tester.widget<AnimatedSwitcher>(
          find.byKey(const ValueKey('product-quantity-1')),
        );
        expect(
          switcher.duration,
          preferences.reduced || preferences.accessible
              ? Duration.zero
              : const Duration(milliseconds: 150),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'compact 2x cart stepper stays inline and checkout can be reached',
    (tester) async {
      controller.dispose();
      final checkout = FakeCheckoutRepository();
      controller = PosController(
        repository: repository,
        checkoutRepository: checkout,
      );
      controller.add(product());
      await pump(tester, size: const Size(360, 800), scale: 2, dark: true);
      await tester.tap(find.byKey(const ValueKey('open-cart')));
      await tester.pumpAndSettle();
      final decrease = find.byTooltip('Decrease Cappuccino quantity');
      final increase = find.byTooltip('Increase Cappuccino quantity');
      expect(tester.getCenter(decrease).dy, tester.getCenter(increase).dy);
      expect(tester.getSize(increase).width, greaterThanOrEqualTo(48));
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(controller.cart.itemCount, 2);
      expect(controller.cart.subtotalMinor, 650);
      final checkoutAction = find.widgetWithText(FilledButton, 'Checkout');
      await tester.ensureVisible(checkoutAction);
      await tester.pumpAndSettle();
      expect(checkoutAction.hitTestable(), findsOneWidget);
      expect(tester.getRect(checkoutAction).bottom, lessThanOrEqualTo(800));
      expect(checkout.checkouts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'maximum draft count/total fits compact summary at $scale text',
      (tester) async {
        for (var id = 1; id <= 50; id++) {
          for (var quantity = 0; quantity < 99; quantity++) {
            controller.add(product(id: id, cents: 999999));
          }
        }
        repository.onProducts = (_, _, _) async =>
            page([product(cents: 999999)]);
        await pump(tester, size: const Size(360, 800), scale: scale);
        expect(controller.cart.itemCount, 4950);
        expect(controller.cart.subtotalMinor, 4949995050);
        expect(find.text(r'$49499950.50 USD'), findsOneWidget);
        expect(find.text('View cart · 4950 items'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'active authoritative order locks every add action and does not resubmit',
    (tester) async {
      controller.dispose();
      final checkout = FakeCheckoutRepository();
      controller = PosController(
        repository: repository,
        checkoutRepository: checkout,
      );
      controller.add(product());
      await pump(tester);
      await controller.checkout!.checkout();
      await tester.pumpAndSettle();
      expect(controller.canEditCart, isFalse);
      final card = tester.widget<PosProductCard>(find.byType(PosProductCard));
      expect(card.onAdd, isNull);
      final before = checkout.checkouts.length;
      await tester.tap(find.byType(PosProductCard));
      await tester.pumpAndSettle();
      expect(checkout.checkouts.length, before);
      expect(controller.cart.itemCount, 1);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'selected product category meets normal-text contrast dark=$dark',
      (tester) async {
        controller.add(product());
        await pump(tester, dark: dark);
        final card = find.byType(PosProductCard);
        final label = tester.widget<Text>(
          find.descendant(of: card, matching: find.text('Coffee')),
        );
        final material = tester.widget<Material>(
          find.descendant(of: card, matching: find.byType(Material)).first,
        );
        final foreground = label.style!.color!.computeLuminance();
        final background = material.color!.computeLuminance();
        final contrast = foreground > background
            ? (foreground + .05) / (background + .05)
            : (background + .05) / (foreground + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      },
    );
  }

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 768),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'native English/Khmer full labels and maximum unit price fit $size dark=$dark scale=$scale',
          (tester) async {
            repository.onProducts = (_, _, _) async => page([
              product(
                name: 'កាហ្វេទឹកដោះគោ · Long Cambodian coffee product name',
                cents: 999999,
              ),
            ]);
            await pump(tester, size: size, dark: dark, scale: scale);
            expect(find.text(r'$9999.99'), findsOneWidget);
            final name = tester.widget<Text>(
              find.text('កាហ្វេទឹកដោះគោ · Long Cambodian coffee product name'),
            );
            expect(name.maxLines, isNull);
            expect(name.overflow, isNot(TextOverflow.ellipsis));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'keyboard inset keeps review action reachable and each semantic add is unique',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pump(tester, scale: 2, keyboard: 280);
        expect(
          find.bySemanticsLabel(RegExp('Add Cappuccino,.*USD')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Search products by name or SKU'),
          findsOneWidget,
        );
        final action = find.byKey(const ValueKey('open-cart'));
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(844 - 280));
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
