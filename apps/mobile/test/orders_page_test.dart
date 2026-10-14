import 'package:coffee_management_mobile/features/orders/domain/order_history_repository.dart';
import 'package:coffee_management_mobile/features/orders/presentation/order_detail_page.dart';
import 'package:coffee_management_mobile/features/orders/presentation/orders_controller.dart';
import 'package:coffee_management_mobile/features/orders/presentation/orders_page.dart';
import 'package:coffee_management_mobile/features/pos/domain/cart.dart';
import 'package:coffee_management_mobile/features/pos/domain/checkout_repository.dart';
import 'package:coffee_management_mobile/features/pos/domain/order.dart';
import 'package:coffee_management_mobile/features/pos/domain/payment.dart';
import 'package:coffee_management_mobile/features/pos/presentation/checkout_controller.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'checkout_test_support.dart';

class FakeOrderRepo implements OrderHistoryRepository {
  List<Order> ordersList = [orderFixture()];
  Order? singleOrder;
  List<Payment> paymentsList = [paymentFixture()];
  bool shouldFail = false;

  @override
  Future<OrderPage> orders({
    OrderStatus? status,
    DateTime? createdFrom,
    DateTime? createdTo,
    int page = 1,
    int perPage = 25,
  }) async {
    if (shouldFail) {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.network);
    }
    var filtered = ordersList;
    if (status != null) {
      filtered = filtered.where((o) => o.status == status).toList();
    }
    return OrderPage(
      items: filtered,
      currentPage: page,
      lastPage: 1,
      perPage: perPage,
      total: filtered.length,
    );
  }

  @override
  Future<Order> order(String reference) async {
    if (shouldFail) {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.network);
    }
    return singleOrder ??
        ordersList.firstWhere((o) => o.reference == reference);
  }

  @override
  Future<PaymentPage> payments(
    String reference, {
    int page = 1,
    int perPage = 25,
  }) async {
    if (shouldFail) {
      throw const OrderHistoryFailure(OrderHistoryFailureKind.network);
    }
    return PaymentPage(
      items: paymentsList,
      currentPage: page,
      lastPage: 1,
      total: paymentsList.length,
    );
  }
}

class FakeCheckoutRepo implements CheckoutRepository {
  Order? cancelledOrder;

  @override
  Future<Order> cancel(String reference) async {
    return cancelledOrder ?? orderFixture(status: 'cancelled');
  }

  @override
  Future<Payment> cash(
    String reference, {
    required String key,
    required int tenderMinor,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Order> createOrder(dynamic intent) async {
    throw UnimplementedError();
  }

  @override
  Future<Payment> external(String reference, {required String key}) async {
    throw UnimplementedError();
  }

  @override
  Future<Order> order(String reference) async {
    return orderFixture();
  }

  @override
  Future<PaymentPage> payments(String reference, {int page = 1}) async {
    return PaymentPage(items: [], currentPage: 1, lastPage: 1, total: 0);
  }

  @override
  Future<Payment> reconcile(String reference, int paymentId) async {
    throw UnimplementedError();
  }
}

void main() {
  late FakeOrderRepo orderRepo;
  late FakeCheckoutRepo checkoutRepo;
  late OrdersController ordersController;
  late CheckoutController checkoutController;

  setUp(() {
    orderRepo = FakeOrderRepo();
    checkoutRepo = FakeCheckoutRepo();
    ordersController = OrdersController(repository: orderRepo);
    checkoutController = CheckoutController(
      repository: checkoutRepo,
      cart: Cart(),
    );
  });

  tearDown(() {
    ordersController.dispose();
    checkoutController.dispose();
  });

  Future<void> pumpOrdersApp(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1.0,
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.buildDarkTheme() : AppTheme.buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: OrdersPage(
            controller: ordersController,
            checkoutController: checkoutController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('OrdersPage compact mobile layout (<600dp)', () {
    testWidgets(
      'renders order history title, status filter chips, and order cards',
      (tester) async {
        await pumpOrdersApp(tester);

        expect(find.text('Order History'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('Paid'), findsOneWidget);
        expect(find.text('Cancelled'), findsOneWidget);
        expect(find.text('Expired'), findsOneWidget);

        // Order card with public reference and exact price
        expect(find.text(orderReference), findsOneWidget);
        expect(find.text(r'$3.25'), findsWidgets);
      },
    );

    testWidgets('tapping status filter chip updates controller filter', (
      tester,
    ) async {
      await pumpOrdersApp(tester);

      // Tap 'Paid' chip
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();

      expect(ordersController.state.filter.status, OrderStatus.paid);
    });

    testWidgets(
      'tapping order card navigates to OrderDetailPage on compact screen',
      (tester) async {
        await pumpOrdersApp(tester);

        // Tap order card
        await tester.tap(find.text(orderReference));
        await tester.pumpAndSettle();

        // Should have pushed OrderDetailPage
        expect(find.byType(OrderDetailPage), findsOneWidget);
        expect(find.text('Order Details'), findsOneWidget);
        expect(find.text(orderReference), findsWidgets);

        // Verify line items and payment section are present
        expect(find.text('Purchased Items'), findsOneWidget);
        expect(find.text('Payment Attempts'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Pending Order Actions'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Pending Order Actions'), findsOneWidget);
        expect(find.text('Resume Payment Workflow'), findsOneWidget);
        expect(find.text('Cancel Unpaid Order'), findsOneWidget);
      },
    );
  });

  group('OrdersPage tablet master-detail layout (≥600dp)', () {
    testWidgets(
      'renders split layout with placeholder before selection, and detail after tap',
      (tester) async {
        await pumpOrdersApp(tester, size: const Size(1024, 768));

        expect(find.text('Order History'), findsOneWidget);
        expect(find.text('Select an Order'), findsOneWidget);

        // Tap order card in master list
        await tester.tap(find.text(orderReference));
        await tester.pumpAndSettle();

        // Right pane should now show details without pushing a new route
        expect(find.byType(OrderDetailPage), findsNothing);
        expect(find.text('Select an Order'), findsNothing);
        expect(find.text('Purchased Items'), findsOneWidget);
        expect(find.text('Payment Attempts'), findsOneWidget);
      },
    );
  });

  group('OrdersPage empty and error states', () {
    testWidgets('displays empty state when no orders found', (tester) async {
      orderRepo.ordersList = [];
      await pumpOrdersApp(tester);

      expect(find.text('No orders found'), findsOneWidget);
    });

    testWidgets('displays error state with retry button on failure', (
      tester,
    ) async {
      orderRepo.shouldFail = true;
      await pumpOrdersApp(tester);

      expect(
        find.text(
          'Unable to connect to the server. Check your network connection.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry after fixing failure
      orderRepo.shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text(orderReference), findsOneWidget);
    });
  });

  group('OrdersPage accessibility and text scaling', () {
    testWidgets(
      'fits small 320x720 screen with 2.0x text scaling without overflow',
      (tester) async {
        await pumpOrdersApp(tester, size: const Size(320, 720), textScale: 2.0);

        // Check for zero overflow errors
        expect(tester.takeException(), isNull);
        expect(find.text('Order History'), findsOneWidget);
      },
    );

    testWidgets(
      'fits tablet 768x1024 screen with 2.0x text scaling in dark mode without overflow',
      (tester) async {
        await pumpOrdersApp(
          tester,
          size: const Size(768, 1024),
          textScale: 2.0,
          dark: true,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Order History'), findsOneWidget);
      },
    );
  });
}
