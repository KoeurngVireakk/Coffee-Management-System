import 'dart:async';

import 'package:coffee_management_mobile/features/orders/domain/order_history_repository.dart';
import 'package:coffee_management_mobile/features/orders/presentation/orders_controller.dart';
import 'package:coffee_management_mobile/features/pos/data/checkout_dto.dart';
import 'package:coffee_management_mobile/features/pos/domain/order.dart';
import 'package:coffee_management_mobile/features/pos/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

import 'checkout_test_support.dart';

class FakeOrderHistoryRepository implements OrderHistoryRepository {
  Future<OrderPage> Function({
    OrderStatus? status,
    DateTime? createdFrom,
    DateTime? createdTo,
    int page,
    int perPage,
  })?
  onOrders;

  Future<Order> Function(String reference)? onOrder;

  Future<PaymentPage> Function(String reference, {int page, int perPage})?
  onPayments;

  final ordersRequests =
      <
        ({
          OrderStatus? status,
          DateTime? createdFrom,
          DateTime? createdTo,
          int page,
          int perPage,
        })
      >[];

  final orderRequests = <String>[];
  final paymentsRequests = <({String reference, int page, int perPage})>[];

  @override
  Future<OrderPage> orders({
    OrderStatus? status,
    DateTime? createdFrom,
    DateTime? createdTo,
    int page = 1,
    int perPage = 25,
  }) async {
    ordersRequests.add((
      status: status,
      createdFrom: createdFrom,
      createdTo: createdTo,
      page: page,
      perPage: perPage,
    ));
    if (onOrders != null) {
      return onOrders!(
        status: status,
        createdFrom: createdFrom,
        createdTo: createdTo,
        page: page,
        perPage: perPage,
      );
    }
    return OrderPage(
      items: [orderFixture(status: status?.name ?? 'pending_payment')],
      currentPage: page,
      lastPage: 1,
      perPage: perPage,
      total: 1,
    );
  }

  @override
  Future<Order> order(String reference) async {
    orderRequests.add(reference);
    if (onOrder != null) {
      return onOrder!(reference);
    }
    return orderFixture();
  }

  @override
  Future<PaymentPage> payments(
    String reference, {
    int page = 1,
    int perPage = 25,
  }) async {
    paymentsRequests.add((reference: reference, page: page, perPage: perPage));
    if (onPayments != null) {
      return onPayments!(reference, page: page, perPage: perPage);
    }
    return PaymentPage(
      items: [paymentFixture()],
      currentPage: page,
      lastPage: 1,
      total: 1,
    );
  }
}

void main() {
  late FakeOrderHistoryRepository repository;
  late OrdersController controller;
  var sessionExpiredCalled = false;

  setUp(() {
    sessionExpiredCalled = false;
    repository = FakeOrderHistoryRepository();
    controller = OrdersController(
      repository: repository,
      onSessionExpired: () => sessionExpiredCalled = true,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('OrdersController initialization and list loading', () {
    test('start loads initial page and populates ready state', () async {
      expect(controller.state.phase, OrderHistoryPhase.initial);
      expect(controller.state.orders, isEmpty);

      await controller.start();

      expect(controller.state.phase, OrderHistoryPhase.ready);
      expect(controller.state.orders.length, 1);
      expect(repository.ordersRequests.length, 1);
      expect(repository.ordersRequests.first.page, 1);

      // Calling start again does nothing
      await controller.start();
      expect(repository.ordersRequests.length, 1);
    });

    test('marks phase as empty when 0 orders returned', () async {
      repository.onOrders =
          ({status, createdFrom, createdTo, page = 1, perPage = 25}) async {
            return OrderPage(
              items: [],
              currentPage: 1,
              lastPage: 1,
              perPage: perPage,
              total: 0,
            );
          };

      await controller.start();

      expect(controller.state.phase, OrderHistoryPhase.empty);
      expect(controller.state.orders, isEmpty);
    });

    test('propagates failure and records error state', () async {
      repository.onOrders =
          ({status, createdFrom, createdTo, page = 1, perPage = 25}) async {
            throw const OrderHistoryFailure(OrderHistoryFailureKind.network);
          };

      await controller.start();

      expect(controller.state.phase, OrderHistoryPhase.error);
      expect(controller.state.failure?.kind, OrderHistoryFailureKind.network);
    });

    test('invokes onSessionExpired on 401 sessionExpired', () async {
      repository.onOrders =
          ({status, createdFrom, createdTo, page = 1, perPage = 25}) async {
            throw const OrderHistoryFailure(
              OrderHistoryFailureKind.sessionExpired,
            );
          };

      await controller.start();

      expect(sessionExpiredCalled, isTrue);
    });
  });

  group('OrdersController filtering', () {
    test('setStatusFilter applies status and reloads from page 1', () async {
      await controller.start();

      await controller.setStatusFilter(OrderStatus.paid);

      expect(controller.state.filter.status, OrderStatus.paid);
      expect(repository.ordersRequests.last.status, OrderStatus.paid);
      expect(repository.ordersRequests.last.page, 1);

      // Same status is a no-op
      final count = repository.ordersRequests.length;
      await controller.setStatusFilter(OrderStatus.paid);
      expect(repository.ordersRequests.length, count);
    });

    test('setDateFilter applies date range and reloads from page 1', () async {
      await controller.start();

      final from = DateTime.utc(2026, 10, 1);
      final to = DateTime.utc(2026, 10, 7);
      await controller.setDateFilter(from, to);

      expect(controller.state.filter.createdFrom, from);
      expect(controller.state.filter.createdTo, to);
      expect(repository.ordersRequests.last.createdFrom, from);
      expect(repository.ordersRequests.last.createdTo, to);
      expect(repository.ordersRequests.last.page, 1);

      await controller.clearDateFilter();
      expect(controller.state.filter.createdFrom, isNull);
      expect(controller.state.filter.createdTo, isNull);
    });

    test('clearAllFilters resets status and dates', () async {
      await controller.start();
      await controller.setStatusFilter(OrderStatus.cancelled);
      expect(controller.state.filter.isActive, isTrue);

      await controller.clearAllFilters();
      expect(controller.state.filter.isActive, isFalse);
      expect(controller.state.filter.status, isNull);
    });
  });

  group('OrdersController pagination and refresh', () {
    test('loadMore appends items and deduplicates references', () async {
      repository.onOrders =
          ({status, createdFrom, createdTo, page = 1, perPage = 25}) async {
            if (page == 1) {
              return OrderPage(
                items: [orderFixture()],
                currentPage: 1,
                lastPage: 2,
                perPage: 1,
                total: 2,
              );
            } else {
              return OrderPage(
                items: [
                  CheckoutDto.order(
                    orderJson()
                      ..['public_reference'] = 'ORD-01K6WY99999999999999999999',
                  ),
                ],
                currentPage: 2,
                lastPage: 2,
                perPage: 1,
                total: 2,
              );
            }
          };

      await controller.start();
      expect(controller.state.orders.length, 1);
      expect(controller.state.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.state.orders.length, 2);
      expect(controller.state.hasMore, isFalse);
    });

    test('refresh preserves existing items while fetching', () async {
      await controller.start();
      expect(controller.state.orders.length, 1);

      final completer = Completer<OrderPage>();
      repository.onOrders =
          ({status, createdFrom, createdTo, page = 1, perPage = 25}) =>
              completer.future;

      final refreshFuture = controller.refresh();
      expect(controller.state.phase, OrderHistoryPhase.refreshing);
      expect(controller.state.orders.length, 1); // Not cleared!

      completer.complete(
        OrderPage(
          items: [orderFixture()],
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 1,
        ),
      );
      await refreshFuture;

      expect(controller.state.phase, OrderHistoryPhase.ready);
    });
  });

  group('OrdersController stale response protection', () {
    test(
      'discards older in-flight request when newer filter is triggered',
      () async {
        final completerA = Completer<OrderPage>();
        final completerB = Completer<OrderPage>();

        repository.onOrders =
            ({status, createdFrom, createdTo, page = 1, perPage = 25}) {
              if (status == OrderStatus.pendingPayment) {
                return completerA.future;
              }
              return completerB.future;
            };

        // Trigger filter A
        final futureA = controller.setStatusFilter(OrderStatus.pendingPayment);

        // Immediately trigger filter B
        final futureB = controller.setStatusFilter(OrderStatus.paid);

        // Complete filter B first
        completerB.complete(
          OrderPage(
            items: [orderFixture(status: 'paid')],
            currentPage: 1,
            lastPage: 1,
            perPage: 25,
            total: 1,
          ),
        );
        await futureB;

        expect(controller.state.filter.status, OrderStatus.paid);
        expect(controller.state.orders.first.status, OrderStatus.paid);

        // Now complete older filter A
        completerA.complete(
          OrderPage(
            items: [orderFixture(status: 'pending_payment')],
            currentPage: 1,
            lastPage: 1,
            perPage: 25,
            total: 1,
          ),
        );
        await futureA;

        // Filter B must NOT be overwritten!
        expect(controller.state.filter.status, OrderStatus.paid);
        expect(controller.state.orders.first.status, OrderStatus.paid);
      },
    );
  });

  group('OrdersController detail selection and recovery eligibility', () {
    test('selectOrder loads order details and payment attempts', () async {
      await controller.start();
      await controller.selectOrder(orderReference);

      expect(controller.detailState.phase, OrderDetailPhase.ready);
      expect(controller.detailState.order?.reference, orderReference);
      expect(controller.detailState.payments.length, 1);
      expect(repository.orderRequests.contains(orderReference), isTrue);
      expect(
        repository.paymentsRequests.any((r) => r.reference == orderReference),
        isTrue,
      );
    });

    test('canResumePayment is true for clean pending order', () async {
      repository.onOrder = (_) async => orderFixture(status: 'pending_payment');
      repository.onPayments = (_, {page = 1, perPage = 25}) async =>
          PaymentPage(items: [], currentPage: 1, lastPage: 1, total: 0);

      await controller.selectOrder(orderReference);

      expect(controller.detailState.order?.status, OrderStatus.pendingPayment);
      expect(controller.detailAllPaymentsLoaded, isTrue);
      expect(controller.detailHasBlockingPayments, isFalse);
      expect(controller.detailRequiresReview, isFalse);
      expect(controller.canResumePayment, isTrue);
      expect(controller.canCancelOrder, isTrue);
    });

    test(
      'canResumePayment is false if payment requires reconciliation',
      () async {
        repository.onOrder = (_) async =>
            orderFixture(status: 'pending_payment');
        repository.onPayments = (_, {page = 1, perPage = 25}) async =>
            PaymentPage(
              items: [
                paymentFixture(
                  method: 'external',
                  status: 'pending',
                  review: true,
                ),
              ],
              currentPage: 1,
              lastPage: 1,
              total: 1,
            );

        await controller.selectOrder(orderReference);

        expect(controller.detailRequiresReview, isTrue);
        expect(controller.canResumePayment, isFalse);
        expect(controller.canCancelOrder, isFalse);
      },
    );

    test(
      'canResumePayment is false if in-flight payment blocks settlement',
      () async {
        repository.onOrder = (_) async =>
            orderFixture(status: 'pending_payment');
        repository.onPayments = (_, {page = 1, perPage = 25}) async =>
            PaymentPage(
              items: [paymentFixture(method: 'external', status: 'initiated')],
              currentPage: 1,
              lastPage: 1,
              total: 1,
            );

        await controller.selectOrder(orderReference);

        expect(controller.detailHasBlockingPayments, isTrue);
        expect(controller.canResumePayment, isFalse);
      },
    );

    test('clearSelectedOrder resets detail state', () async {
      await controller.selectOrder(orderReference);
      expect(controller.detailState.order, isNotNull);

      controller.clearSelectedOrder();
      expect(controller.detailState.order, isNull);
      expect(controller.detailState.payments, isEmpty);
      expect(controller.detailState.phase, OrderDetailPhase.initial);
    });
  });
}
