import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../pos/domain/order.dart';
import '../../pos/domain/payment.dart';
import '../domain/order_filter.dart';
import '../domain/order_history_repository.dart';

enum OrderHistoryPhase {
  initial,
  loading,
  ready,
  empty,
  refreshing,
  loadingMore,
  error,
}

enum OrderDetailPhase {
  initial,
  loading,
  ready,
  refreshing,
  loadingMorePayments,
  error,
}

class OrderHistoryState {
  OrderHistoryState({
    this.phase = OrderHistoryPhase.initial,
    List<Order> orders = const [],
    this.page,
    OrderFilter? filter,
    this.failure,
  }) : orders = List.unmodifiable(orders),
       filter = filter ?? OrderFilter();

  final OrderHistoryPhase phase;
  final List<Order> orders;
  final OrderPage? page;
  final OrderFilter filter;
  final OrderHistoryFailure? failure;

  bool get busy =>
      phase == OrderHistoryPhase.loading ||
      phase == OrderHistoryPhase.refreshing ||
      phase == OrderHistoryPhase.loadingMore;

  bool get hasMore => page?.hasMore ?? false;
}

class OrderDetailState {
  OrderDetailState({
    this.phase = OrderDetailPhase.initial,
    this.order,
    List<Payment> payments = const [],
    this.paymentPage,
    this.failure,
  }) : payments = List.unmodifiable(payments);

  final OrderDetailPhase phase;
  final Order? order;
  final List<Payment> payments;
  final PaymentPage? paymentPage;
  final OrderHistoryFailure? failure;

  bool get busy =>
      phase == OrderDetailPhase.loading ||
      phase == OrderDetailPhase.refreshing ||
      phase == OrderDetailPhase.loadingMorePayments;

  bool get hasMorePayments =>
      paymentPage != null && paymentPage!.currentPage < paymentPage!.lastPage;
}

/// Session-owned controller managing order history listing, filtering, pagination,
/// and authoritative order detail queries.
class OrdersController extends ChangeNotifier {
  OrdersController({
    required this.repository,
    this.onSessionExpired,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final OrderHistoryRepository repository;
  final VoidCallback? onSessionExpired;
  final DateTime Function() _clock;

  OrderHistoryState _state = OrderHistoryState();
  OrderHistoryState get state => _state;

  OrderDetailState _detailState = OrderDetailState();
  OrderDetailState get detailState => _detailState;

  int _listGeneration = 0;
  int? _activeListGeneration;
  int _detailGeneration = 0;
  int? _activeDetailGeneration;

  DateTime? _retryAt;
  Timer? _cooldownTimer;
  bool _disposed = false;
  bool _expired = false;
  bool _started = false;

  DateTime get now => _clock().toUtc();
  bool get coolingDown => _retryAt != null && now.isBefore(_retryAt!);

  bool get detailRequiresReview =>
      _detailState.payments.any((p) => p.reconciliationRequired);

  bool get detailHasBlockingPayments =>
      _detailState.payments.any((p) => p.blocksSettlement);

  bool get detailAllPaymentsLoaded =>
      _detailState.paymentPage != null && !_detailState.hasMorePayments;

  bool get canResumePayment =>
      _detailState.order?.status == OrderStatus.pendingPayment &&
      detailAllPaymentsLoaded &&
      !detailHasBlockingPayments &&
      !detailRequiresReview &&
      !_detailState.busy &&
      !coolingDown;

  bool get canCancelOrder => canResumePayment;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_started || _disposed || _expired) return;
    _started = true;
    await _loadOrders();
  }

  Future<void> refresh() async {
    if (_disposed || _expired || state.busy) return;
    await _loadOrders(refreshing: true);
  }

  Future<void> loadMore() async {
    if (_disposed || _expired || state.busy || !state.hasMore) return;
    await _loadOrders(more: true);
  }

  Future<void> retry() async {
    if (_disposed || _expired || state.busy) return;
    await _loadOrders(more: state.orders.isNotEmpty && state.hasMore);
  }

  Future<void> setStatusFilter(OrderStatus? status) async {
    if (_disposed || _expired || status == _state.filter.status) return;
    final updatedFilter = _state.filter.copyWith(status: () => status);
    await _applyFilter(updatedFilter);
  }

  Future<void> setDateFilter(DateTime? from, DateTime? to) async {
    if (_disposed || _expired) return;
    if (from == _state.filter.createdFrom && to == _state.filter.createdTo) {
      return;
    }
    final updatedFilter = _state.filter.copyWith(
      createdFrom: () => from,
      createdTo: () => to,
    );
    await _applyFilter(updatedFilter);
  }

  Future<void> clearDateFilter() async {
    if (_disposed || _expired) return;
    if (_state.filter.createdFrom == null && _state.filter.createdTo == null) {
      return;
    }
    final updatedFilter = _state.filter.copyWith(
      createdFrom: () => null,
      createdTo: () => null,
    );
    await _applyFilter(updatedFilter);
  }

  Future<void> clearAllFilters() async {
    if (_disposed || _expired || !_state.filter.isActive) return;
    await _applyFilter(OrderFilter());
  }

  Future<void> _applyFilter(OrderFilter newFilter) async {
    _listGeneration++;
    _state = OrderHistoryState(
      phase: _state.orders.isEmpty
          ? OrderHistoryPhase.loading
          : OrderHistoryPhase.refreshing,
      orders: _state.orders,
      filter: newFilter,
    );
    _notify();
    await _loadOrders(filter: newFilter);
  }

  Future<void> _loadOrders({
    bool more = false,
    bool refreshing = false,
    OrderFilter? filter,
  }) async {
    if (_disposed || _expired) return;
    final currentFilter = filter ?? _state.filter;
    final previous = _state;
    final generation = ++_listGeneration;
    _activeListGeneration = generation;

    final targetPage = more ? (previous.page?.currentPage ?? 1) + 1 : 1;

    _state = OrderHistoryState(
      phase: more
          ? OrderHistoryPhase.loadingMore
          : refreshing || previous.orders.isNotEmpty
          ? OrderHistoryPhase.refreshing
          : OrderHistoryPhase.loading,
      orders: previous.orders,
      page: more ? previous.page : null,
      filter: currentFilter,
    );
    _notify();

    try {
      final page = await repository.orders(
        status: currentFilter.status,
        createdFrom: currentFilter.createdFrom,
        createdTo: currentFilter.createdTo,
        page: targetPage,
      );

      if (_disposed || _expired || generation != _listGeneration) return;

      final merged = <String, Order>{
        if (more)
          for (final order in previous.orders) order.reference: order,
        for (final order in page.items) order.reference: order,
      };

      _state = OrderHistoryState(
        phase: merged.isEmpty
            ? OrderHistoryPhase.empty
            : OrderHistoryPhase.ready,
        orders: merged.values.toList(),
        page: page,
        filter: currentFilter,
      );
    } on OrderHistoryFailure catch (failure) {
      _handleFailure(failure);
      if (_disposed || generation != _listGeneration) return;

      _state = OrderHistoryState(
        phase: OrderHistoryPhase.error,
        orders: previous.orders,
        page: more ? previous.page : null,
        filter: currentFilter,
        failure: failure,
      );
    } finally {
      if (_activeListGeneration == generation) {
        _activeListGeneration = null;
      }
    }
    _notify();
  }

  Future<void> selectOrder(String reference, {Order? initialOrder}) async {
    if (_disposed || _expired) return;
    final generation = ++_detailGeneration;
    _activeDetailGeneration = generation;

    _detailState = OrderDetailState(
      phase: initialOrder != null
          ? OrderDetailPhase.refreshing
          : OrderDetailPhase.loading,
      order: initialOrder ?? _detailState.order,
      payments: initialOrder != null && initialOrder.acceptedPayment != null
          ? [initialOrder.acceptedPayment!]
          : const [],
    );
    _notify();

    try {
      final order = await repository.order(reference);
      if (_disposed || _expired || generation != _detailGeneration) return;

      final paymentPage = await repository.payments(reference);
      if (_disposed || _expired || generation != _detailGeneration) return;

      _detailState = OrderDetailState(
        phase: OrderDetailPhase.ready,
        order: order,
        payments: paymentPage.items,
        paymentPage: paymentPage,
      );

      // Keep order in the main list up to date if present
      _syncOrderInList(order);
    } on OrderHistoryFailure catch (failure) {
      _handleFailure(failure);
      if (_disposed || generation != _detailGeneration) return;

      _detailState = OrderDetailState(
        phase: OrderDetailPhase.error,
        order: initialOrder ?? _detailState.order,
        payments: _detailState.payments,
        paymentPage: _detailState.paymentPage,
        failure: failure,
      );
    } finally {
      if (_activeDetailGeneration == generation) {
        _activeDetailGeneration = null;
      }
    }
    _notify();
  }

  Future<void> refreshOrderDetail() async {
    if (_disposed || _expired || _detailState.busy) return;
    final order = _detailState.order;
    if (order == null) return;
    await selectOrder(order.reference, initialOrder: order);
  }

  Future<void> loadMoreDetailPayments() async {
    if (_disposed ||
        _expired ||
        _detailState.busy ||
        !_detailState.hasMorePayments) {
      return;
    }
    final order = _detailState.order;
    final previousPage = _detailState.paymentPage;
    if (order == null || previousPage == null) return;

    final generation = ++_detailGeneration;
    _activeDetailGeneration = generation;

    _detailState = OrderDetailState(
      phase: OrderDetailPhase.loadingMorePayments,
      order: order,
      payments: _detailState.payments,
      paymentPage: previousPage,
    );
    _notify();

    try {
      final nextPage = await repository.payments(
        order.reference,
        page: previousPage.currentPage + 1,
      );

      if (_disposed || _expired || generation != _detailGeneration) return;

      final merged = <int, Payment>{
        for (final p in _detailState.payments) p.id: p,
        for (final p in nextPage.items) p.id: p,
      };

      _detailState = OrderDetailState(
        phase: OrderDetailPhase.ready,
        order: order,
        payments: merged.values.toList(),
        paymentPage: nextPage,
      );
    } on OrderHistoryFailure catch (failure) {
      _handleFailure(failure);
      if (_disposed || generation != _detailGeneration) return;

      _detailState = OrderDetailState(
        phase: OrderDetailPhase.error,
        order: order,
        payments: _detailState.payments,
        paymentPage: previousPage,
        failure: failure,
      );
    } finally {
      if (_activeDetailGeneration == generation) {
        _activeDetailGeneration = null;
      }
    }
    _notify();
  }

  void clearSelectedOrder() {
    if (_disposed) return;
    _detailGeneration++;
    _detailState = OrderDetailState();
    _notify();
  }

  void _syncOrderInList(Order updated) {
    final index = _state.orders.indexWhere(
      (o) => o.reference == updated.reference,
    );
    if (index >= 0) {
      final updatedList = List<Order>.of(_state.orders);
      updatedList[index] = updated;
      _state = OrderHistoryState(
        phase: _state.phase,
        orders: updatedList,
        page: _state.page,
        filter: _state.filter,
        failure: _state.failure,
      );
    }
  }

  void _handleFailure(OrderHistoryFailure failure) {
    if (!_disposed &&
        !_expired &&
        failure.kind == OrderHistoryFailureKind.sessionExpired) {
      _expired = true;
      onSessionExpired?.call();
    }
    if (failure.kind == OrderHistoryFailureKind.rateLimited) {
      final seconds = (failure.retryAfterSeconds ?? 30).clamp(1, 3600);
      _retryAt = now.add(Duration(seconds: seconds));
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(Duration(seconds: seconds), () {
        if (!_disposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _listGeneration++;
    _detailGeneration++;
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
