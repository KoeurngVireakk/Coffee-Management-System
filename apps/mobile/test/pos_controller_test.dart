import 'dart:async';
import 'package:coffee_management_mobile/features/pos/domain/catalog.dart';
import 'package:coffee_management_mobile/features/pos/domain/catalog_repository.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_controller.dart';
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

  test(
    'initial load starts once, with independent categories and products',
    () async {
      final pending = Completer<CatalogPage<CatalogProduct>>();
      repository.onProducts = (_, _, _) => pending.future;
      final initial = controller.start();
      await controller.start();
      expect(controller.products.phase, CatalogPhase.loading);
      pending.complete(page([product()]));
      await initial;
      expect(controller.products.phase, CatalogPhase.ready);
      expect(controller.categories.items.single.name, 'Coffee');
      expect(repository.productRequests.length, 1);
    },
  );
  test(
    'failed initial load and retry preserve cart and show controlled failure',
    () async {
      controller.add(product());
      repository.onProducts = (_, _, _) async =>
          throw const CatalogFailure(CatalogFailureKind.network);
      await controller.start();
      expect(controller.products.phase, CatalogPhase.error);
      expect(controller.products.failure!.kind, CatalogFailureKind.network);
      expect(controller.cart.subtotalMinor, 325);
      repository.onProducts = null;
      await controller.retryProducts();
      expect(controller.products.phase, CatalogPhase.ready);
      expect(controller.cart.itemCount, 1);
    },
  );
  test('category change resets pages and preserves cart', () async {
    await controller.start();
    controller.add(product());
    await controller.selectCategory(1);
    expect(repository.productRequests.last, (
      page: 1,
      categoryId: 1,
      search: '',
    ));
    expect(controller.cart.itemCount, 1);
    await controller.selectCategory(999);
    expect(repository.productRequests.length, 2);
    await controller.selectCategory(null);
    expect(controller.categoryId, isNull);
  });
  test(
    'selected category remains identifiable when refreshed first page omits it',
    () async {
      await controller.start();
      await controller.selectCategory(1);
      repository.onCategories = (_) async =>
          page([category(id: 2, name: 'Tea')]);
      await controller.refresh();
      expect(controller.categoryId, 1);
      expect(controller.selectedCategory!.name, 'Coffee');
      await controller.selectCategory(null);
      expect(controller.selectedCategory, isNull);
    },
  );
  test(
    'load more serializes calls, merges IDs and stops at last page',
    () async {
      repository.onProducts = (_, _, _) async =>
          page([product()], last: 2, total: 2);
      await controller.start();
      final pending = Completer<CatalogPage<CatalogProduct>>();
      repository.onProducts = (_, _, _) => pending.future;
      final more = controller.loadMoreProducts();
      await controller.loadMoreProducts();
      expect(repository.productRequests.length, 2);
      expect(controller.products.phase, CatalogPhase.loadingMore);
      pending.complete(
        page([product(cents: 450), product(id: 2)], current: 2, last: 2),
      );
      await more;
      expect(controller.products.items.map((item) => item.id), [1, 2]);
      expect(controller.products.items.first.priceMinor, 450);
      await controller.loadMoreProducts();
      expect(repository.productRequests.length, 2);
    },
  );
  test(
    'failed next page retains previous data, page pointer and cart for retry',
    () async {
      repository.onProducts = (_, _, _) async =>
          page([product()], last: 2, total: 2);
      await controller.start();
      controller.add(product());
      repository.onProducts = (_, _, _) async =>
          throw const CatalogFailure(CatalogFailureKind.server);
      await controller.loadMoreProducts();
      expect(controller.products.items.length, 1);
      expect(controller.products.page!.currentPage, 1);
      expect(controller.cart.subtotalMinor, 325);
      repository.onProducts = (_, _, _) async =>
          page([product(id: 2)], current: 2, last: 2);
      await controller.loadMoreProducts();
      expect(repository.productRequests.map((request) => request.page), [
        1,
        2,
        2,
      ]);
      expect(controller.products.items.length, 2);
    },
  );
  test('category pagination is bounded and independent', () async {
    repository.onCategories = (_) async =>
        page([category()], last: 2, total: 2);
    await controller.start();
    final pending = Completer<CatalogPage<CatalogCategory>>();
    repository.onCategories = (_) => pending.future;
    final more = controller.loadMoreCategories();
    await controller.loadMoreCategories();
    pending.complete(page([category(id: 2, name: 'Tea')], current: 2, last: 2));
    await more;
    await controller.loadMoreCategories();
    expect(repository.categoryRequests, [1, 2]);
    expect(controller.categories.items.map((item) => item.name), [
      'Coffee',
      'Tea',
    ]);
    expect(repository.productRequests.length, 1);
  });
  testWidgets('typing debounces and invalidates responses before timer fires', (
    tester,
  ) async {
    await controller.start();
    final first = Completer<CatalogPage<CatalogProduct>>();
    repository.onProducts = (_, _, _) => first.future;
    controller.setSearch('c');
    await tester.pump(const Duration(milliseconds: 100));
    controller.setSearch('ca');
    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.productRequests.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.productRequests.last.search, 'ca');
    controller.setSearch('cappuccino');
    first.complete(page([product(name: 'Stale coffee')]));
    await tester.pump();
    expect(controller.products.items.single.name, 'Cappuccino');
    expect(controller.products.phase, CatalogPhase.refreshing);
    repository.onProducts = (_, _, _) async =>
        page([product(name: 'Fresh cappuccino')]);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.products.items.single.name, 'Fresh cappuccino');
  });
  testWidgets('later request wins when earlier search returns last', (
    tester,
  ) async {
    await controller.start();
    final earlier = Completer<CatalogPage<CatalogProduct>>();
    repository.onProducts = (_, _, _) => earlier.future;
    controller.setSearch('ca');
    await tester.pump(const Duration(milliseconds: 300));
    controller.setSearch('cappuccino');
    repository.onProducts = (_, _, _) async =>
        page([product(id: 2, name: 'Latest')]);
    await tester.pump(const Duration(milliseconds: 300));
    earlier.complete(page([product(name: 'Stale')]));
    await tester.pump();
    expect(controller.products.items.single.name, 'Latest');
    expect(controller.search, 'cappuccino');
  });
  test('category response supersedes in-flight pagination', () async {
    repository.onProducts = (_, _, _) async =>
        page([product()], last: 2, total: 2);
    await controller.start();
    final earlier = Completer<CatalogPage<CatalogProduct>>();
    repository.onProducts = (_, _, _) => earlier.future;
    final more = controller.loadMoreProducts();
    repository.onProducts = (_, _, _) async => page([product(id: 3)]);
    await controller.selectCategory(1);
    earlier.complete(page([product(id: 2)], current: 2, last: 2));
    await more;
    expect(controller.products.items.single.id, 3);
    expect(controller.products.page!.currentPage, 1);
  });
  testWidgets(
    'search enforces 80 Unicode characters and preserves cart on empty results',
    (tester) async {
      await controller.start();
      controller.add(product());
      repository.onProducts = (_, _, _) async => page([]);
      controller.setSearch('ក' * 81);
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.productRequests.last.search.runes.length, 80);
      expect(controller.products.phase, CatalogPhase.empty);
      expect(controller.cart.subtotalMinor, 325);
    },
  );
  test(
    'refresh prevents duplicate requests, resets pages and updates previews',
    () async {
      await controller.start();
      controller.add(product());
      controller.add(product());
      final pending = Completer<CatalogPage<CatalogProduct>>();
      repository.onProducts = (_, _, _) => pending.future;
      final refresh = controller.refresh();
      await controller.refresh();
      await controller.retryProducts();
      expect(repository.productRequests.length, 2);
      expect(controller.cart.subtotalMinor, 650);
      pending.complete(page([product(cents: 450)]));
      await refresh;
      expect(controller.cart.subtotalMinor, 900);
      expect(controller.cart.quantityFor(1), 2);
    },
  );
  test(
    '403 stays in feature without session invalidation; 401 invalidates once',
    () async {
      var expired = 0;
      final secured = PosController(
        repository: repository,
        onSessionExpired: () => expired++,
      );
      addTearDown(secured.dispose);
      repository.onProducts = (_, _, _) async =>
          throw const CatalogFailure(CatalogFailureKind.forbidden);
      await secured.start();
      expect(expired, 0);
      expect(secured.products.failure!.kind, CatalogFailureKind.forbidden);
      repository.onProducts = (_, _, _) async =>
          throw const CatalogFailure(CatalogFailureKind.sessionExpired);
      await secured.retryProducts();
      await secured.retryProducts();
      expect(expired, 1);
    },
  );
  test('even a stale same-session 401 proves the token unusable', () async {
    var expired = 0;
    final secured = PosController(
      repository: repository,
      onSessionExpired: () => expired++,
    );
    addTearDown(secured.dispose);
    final earlier = Completer<CatalogPage<CatalogProduct>>();
    repository.onProducts = (_, _, _) => earlier.future;
    final initial = secured.start();
    repository.onProducts = (_, _, _) async => page([product()]);
    await secured.selectCategory(
      1,
    ); // categories have completed in microtasks below
    secured.setSearch('new');
    earlier.completeError(
      const CatalogFailure(CatalogFailureKind.sessionExpired),
    );
    await initial;
    expect(expired, 1);
  });
  testWidgets('dispose cancels debounce and ignores late completion', (
    tester,
  ) async {
    final disposed = PosController(repository: repository);
    final pending = Completer<CatalogPage<CatalogProduct>>();
    repository.onProducts = (_, _, _) => pending.future;
    final initial = disposed.start();
    disposed.setSearch('new');
    disposed.dispose();
    pending.complete(page([product()]));
    await initial;
    await tester.pump(const Duration(seconds: 1));
    expect(repository.productRequests.length, 1);
    expect(disposed.products.items, isEmpty);
  });
  test(
    'category failure does not hide products and retry is independent',
    () async {
      repository.onCategories = (_) async =>
          throw const CatalogFailure(CatalogFailureKind.invalidResponse);
      await controller.start();
      expect(controller.products.phase, CatalogPhase.ready);
      expect(controller.categories.phase, CatalogPhase.error);
      repository.onCategories = null;
      await controller.retryCategories();
      expect(controller.categories.phase, CatalogPhase.ready);
      expect(repository.productRequests.length, 1);
    },
  );
}
