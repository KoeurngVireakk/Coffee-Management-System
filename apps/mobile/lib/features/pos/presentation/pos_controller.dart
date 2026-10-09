import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/cart.dart';
import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';
import '../domain/checkout_repository.dart';
import 'checkout_controller.dart';

enum CatalogPhase {
  initial,
  loading,
  ready,
  empty,
  refreshing,
  loadingMore,
  error,
}

class CatalogState<T> {
  CatalogState({
    this.phase = CatalogPhase.initial,
    List<T> items = const [],
    this.page,
    this.failure,
  }) : items = List.unmodifiable(items);
  final CatalogPhase phase;
  final List<T> items;
  final CatalogPage<T>? page;
  final CatalogFailure? failure;
  bool get busy =>
      phase == CatalogPhase.loading ||
      phase == CatalogPhase.refreshing ||
      phase == CatalogPhase.loadingMore;
  bool get hasMore => page?.hasMore ?? false;
}

/// Session-owned state, independent of route/layout/theme and cart rendering.
class PosController extends ChangeNotifier {
  PosController({
    required this.repository,
    this.onSessionExpired,
    CheckoutRepository? checkoutRepository,
    this.searchDelay = const Duration(milliseconds: 300),
  }) {
    checkout = checkoutRepository == null
        ? null
        : CheckoutController(
            repository: checkoutRepository,
            cart: cart,
            onSessionExpired: onSessionExpired,
          );
    checkout?.addListener(_notify);
  }
  final CatalogRepository repository;
  final VoidCallback? onSessionExpired;
  final Duration searchDelay;
  final Cart cart = Cart();
  late final CheckoutController? checkout;
  bool get canEditCart => checkout?.canEditCart ?? true;
  CatalogState<CatalogCategory> _categories = CatalogState();
  CatalogState<CatalogProduct> _products = CatalogState();
  CatalogState<CatalogCategory> get categories => _categories;
  CatalogState<CatalogProduct> get products => _products;
  String _search = '';
  String get search => _search;
  int? _categoryId;
  int? get categoryId => _categoryId;
  CatalogCategory? _selectedCategory;
  CatalogCategory? get selectedCategory => _selectedCategory;
  Timer? _debounce;
  int _productGeneration = 0;
  int? _activeProductGeneration;
  int _categoryGeneration = 0;
  bool _disposed = false;
  bool _expired = false;
  bool _started = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    await Future.wait([_loadCategories(), _loadProducts()]);
  }

  Future<void> refresh() async {
    if (_disposed || _expired || products.busy || categories.busy) return;
    _debounce?.cancel();
    await Future.wait([_loadCategories(), _loadProducts()]);
  }

  void setSearch(String value) {
    final term = String.fromCharCodes(value.runes.take(80)).trim();
    if (_disposed || _expired || term == _search) return;
    _search = term;
    // Invalidate at input time, before the next debounce request is sent.
    _productGeneration++;
    _debounce?.cancel();
    _products = CatalogState(
      phase: CatalogPhase.refreshing,
      items: products.items,
    );
    _notify();
    _debounce = Timer(searchDelay, _loadProducts);
  }

  Future<void> selectCategory(int? id) async {
    if (_disposed || _expired || id == _categoryId) return;
    if (id != null && !categories.items.any((category) => category.id == id)) {
      return;
    }
    _categoryId = id;
    _selectedCategory = id == null
        ? null
        : categories.items.firstWhere((category) => category.id == id);
    _productGeneration++;
    _debounce?.cancel();
    await _loadProducts();
  }

  Future<void> retryProducts() => _loadProducts();
  Future<void> retryCategories() => _loadCategories();
  Future<void> loadMoreProducts() => _loadProducts(more: true);
  Future<void> loadMoreCategories() => _loadCategories(more: true);

  Future<void> _loadProducts({bool more = false}) async {
    if (_disposed || _expired) return;
    if (more && (products.busy || !products.hasMore)) return;
    if (!more && _activeProductGeneration == _productGeneration) return;
    _debounce?.cancel();
    final previous = products;
    final generation = ++_productGeneration;
    _activeProductGeneration = generation;
    final pageNumber = more ? previous.page!.currentPage + 1 : 1;
    _products = CatalogState(
      phase: more
          ? CatalogPhase.loadingMore
          : previous.items.isEmpty
          ? CatalogPhase.loading
          : CatalogPhase.refreshing,
      items: previous.items,
      page: more ? previous.page : null,
    );
    _notify();
    try {
      final page = await repository.products(
        page: pageNumber,
        categoryId: categoryId,
        search: search,
      );
      if (_disposed || _expired || generation != _productGeneration) return;
      final merged = <int, CatalogProduct>{
        if (more)
          for (final product in previous.items) product.id: product,
        for (final product in page.items) product.id: product,
      };
      if (canEditCart) cart.updatePreviews(page.items);
      _products = CatalogState(
        phase: merged.isEmpty ? CatalogPhase.empty : CatalogPhase.ready,
        items: merged.values.toList(),
        page: page,
      );
    } on CatalogFailure catch (failure) {
      _handleFailure(failure);
      if (_disposed || generation != _productGeneration) return;
      _products = CatalogState(
        phase: CatalogPhase.error,
        items: previous.items,
        page: more ? previous.page : null,
        failure: failure,
      );
    } finally {
      if (_activeProductGeneration == generation) {
        _activeProductGeneration = null;
      }
    }
    _notify();
  }

  Future<void> _loadCategories({bool more = false}) async {
    if (_disposed ||
        _expired ||
        categories.busy ||
        (more && !categories.hasMore)) {
      return;
    }
    final previous = categories;
    final generation = ++_categoryGeneration;
    _categories = CatalogState(
      phase: more
          ? CatalogPhase.loadingMore
          : previous.items.isEmpty
          ? CatalogPhase.loading
          : CatalogPhase.refreshing,
      items: previous.items,
      page: more ? previous.page : null,
    );
    _notify();
    try {
      final page = await repository.categories(
        page: more ? previous.page!.currentPage + 1 : 1,
      );
      if (_disposed || _expired || generation != _categoryGeneration) return;
      final merged = <int, CatalogCategory>{
        if (more)
          for (final category in previous.items) category.id: category,
        for (final category in page.items) category.id: category,
      };
      _categories = CatalogState(
        phase: merged.isEmpty ? CatalogPhase.empty : CatalogPhase.ready,
        items: merged.values.toList(),
        page: page,
      );
    } on CatalogFailure catch (failure) {
      _handleFailure(failure);
      if (_disposed || generation != _categoryGeneration) return;
      _categories = CatalogState(
        phase: CatalogPhase.error,
        items: previous.items,
        page: more ? previous.page : null,
        failure: failure,
      );
    }
    _notify();
  }

  void _handleFailure(CatalogFailure failure) {
    if (!_disposed &&
        !_expired &&
        failure.kind == CatalogFailureKind.sessionExpired) {
      _expired = true;
      _debounce?.cancel();
      onSessionExpired?.call();
    }
  }

  CartLimit? add(CatalogProduct product) {
    if (!canEditCart) return CartLimit.checkoutLocked;
    final limit = cart.add(product);
    _notify();
    return limit;
  }

  CartLimit? increment(int id) {
    if (!canEditCart) return CartLimit.checkoutLocked;
    final limit = cart.increment(id);
    _notify();
    return limit;
  }

  void decrement(int id) {
    if (!canEditCart) return;
    cart.decrement(id);
    _notify();
  }

  void remove(int id) {
    if (!canEditCart) return;
    cart.remove(id);
    _notify();
  }

  void clearCart() {
    if (!canEditCart) return;
    cart.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _productGeneration++;
    _categoryGeneration++;
    _debounce?.cancel();
    checkout?.removeListener(_notify);
    checkout?.dispose();
    super.dispose();
  }
}
