import 'dart:async';
import 'package:coffee_management_mobile/features/pos/domain/cart.dart';
import 'package:coffee_management_mobile/features/pos/domain/checkout_repository.dart';
import 'package:coffee_management_mobile/features/pos/domain/order.dart';
import 'package:coffee_management_mobile/features/pos/domain/payment.dart';
import 'package:coffee_management_mobile/features/pos/presentation/checkout_controller.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'checkout_test_support.dart';
import 'pos_test_support.dart';

void main() {
  late FakeCheckoutRepository repository;
  late Cart cart;
  late CheckoutController controller;
  var keyCount = 0;
  setUp(() {
    keyCount = 0;
    repository = FakeCheckoutRepository();
    cart = Cart()..add(product());
    controller = CheckoutController(
      repository: repository,
      cart: cart,
      keyGenerator: () => 'synthetic-key-${++keyCount}',
    );
  });
  tearDown(() => controller.dispose());
  test('unavailable secure randomness fails closed before a request', () async {
    final secured = CheckoutController(
      repository: repository,
      cart: cart,
      keyGenerator: () =>
          throw UnsupportedError('Synthetic missing secure source'),
    );
    addTearDown(secured.dispose);
    await secured.checkout();
    expect(repository.checkouts, isEmpty);
    expect(secured.state.failure!.message, contains('secure request identity'));
    expect(cart.itemCount, 1);
  });

  test(
    'overlapping cash requests share one in-flight mutation and guard cancellation',
    () async {
      await controller.checkout();
      final pending = Completer<Payment>();
      repository.onCash = (_, _, _) => pending.future;
      final first = controller.cash(1000);
      await controller.cash(1000);
      await controller.cancel();
      await controller.external();
      expect(repository.cashRequests.length, 1);
      expect(repository.cancellations, isEmpty);
      expect(repository.externalRequests, isEmpty);
      pending.complete(paymentFixture());
      await first;
    },
  );

  test(
    'overlapping reconciliation requests check existing attempt only once',
    () async {
      await controller.checkout();
      final attempt = paymentFixture(method: 'external', status: 'pending');
      repository.attempts = [attempt];
      await controller.refreshOrder();
      final pending = Completer<Payment>();
      repository.onReconcile = (_, _) => pending.future;
      final first = controller.checkPayment();
      await controller.checkPayment();
      expect(repository.reconciles.length, 1);
      pending.complete(attempt);
      await first;
    },
  );

  test(
    'checkout becomes authoritative pending order without clearing the draft',
    () async {
      repository.serverUnitMinor = 450;
      await controller.checkout();
      expect(controller.state.phase, CheckoutPhase.pendingPayment);
      expect(controller.state.order!.totalMinor, 450);
      expect(controller.previewTotalMinor, 325);
      expect(controller.canEditCart, isFalse);
      expect(controller.canChoosePayment, isTrue);
      expect(repository.orderReads, [orderReference]);
      expect(repository.paymentReads.length, 1);
      expect(cart.totalMinor, 325);
    },
  );
  test('overlapping checkout presses create one request', () async {
    final pending = Completer<Order>();
    repository.onCreate = (_) => pending.future;
    final first = controller.checkout();
    await controller.checkout();
    expect(repository.checkouts.length, 1);
    expect(controller.state.busy, isTrue);
    expect(cart.distinctCount, 1);
    pending.complete(orderFixture());
    await first;
    expect(controller.state.phase, CheckoutPhase.pendingPayment);
  });
  for (final kind in [
    CheckoutFailureKind.network,
    CheckoutFailureKind.server,
    CheckoutFailureKind.invalidResponse,
  ]) {
    test(
      'checkout $kind retains exact snapshot/key and retry replays it',
      () async {
        repository.onCreate = (_) async => throw CheckoutFailure(kind);
        await controller.checkout();
        final original = repository.checkouts.single;
        expect(controller.state.phase, CheckoutPhase.requestUncertain);
        expect(controller.canCheckout, isFalse);
        expect(controller.canEditCart, isFalse);
        expect(controller.canStartNewOrder, isFalse);
        repository.onCreate = null;
        await controller.retrySameRequest();
        expect(repository.checkouts.last, same(original));
        expect(repository.checkouts.last.key, original.key);
        expect(keyCount, 1);
        expect(controller.state.phase, CheckoutPhase.pendingPayment);
      },
    );
  }
  test(
    'a changed draft after deterministic 422 gets a new semantic key',
    () async {
      repository.onCreate = (_) async => throw const CheckoutFailure(
        CheckoutFailureKind.validation,
        errors: {
          'items': ['A selected product is unavailable.'],
        },
      );
      await controller.checkout();
      expect(controller.canEditCart, isTrue);
      final key = repository.checkouts.single.key;
      cart.increment(1);
      repository.onCreate = null;
      await controller.checkout();
      expect(repository.checkouts.last.key, isNot(key));
      expect(repository.checkouts.last.items.single.quantity, 2);
    },
  );
  test(
    'unchanged semantic draft reuses its key after a deterministic rejection',
    () async {
      repository.onCreate = (_) async =>
          throw const CheckoutFailure(CheckoutFailureKind.validation);
      await controller.checkout();
      repository.onCreate = null;
      await controller.checkout();
      expect(
        repository.checkouts.map((intent) => intent.key).toSet().length,
        1,
      );
    },
  );
  test(
    '403 after earlier ambiguity never unlocks the original uncertain checkout',
    () async {
      repository.onCreate = (_) async =>
          throw const CheckoutFailure(CheckoutFailureKind.network);
      await controller.checkout();
      repository.onCreate = (_) async =>
          throw const CheckoutFailure(CheckoutFailureKind.forbidden);
      await controller.retrySameRequest();
      expect(controller.state.phase, CheckoutPhase.requestUncertain);
      expect(controller.canEditCart, isFalse);
      expect(controller.state.retryOperation, CheckoutOperation.checkout);
    },
  );
  test(
    'checkout replay may return paid, but success still requires GET and attempt review',
    () async {
      repository.onCreate = (_) async {
        repository.currentOrder = orderFixture(status: 'paid');
        return repository.currentOrder;
      };
      await controller.checkout();
      expect(controller.state.phase, CheckoutPhase.paid);
      expect(repository.orderReads.length, 1);
      expect(repository.paymentReads.length, 1);
    },
  );
  test(
    'cash confirms using separate key and server tender/change, then GET proves paid',
    () async {
      await controller.checkout();
      controller.chooseCash();
      controller.setCashInput('10.00');
      await controller.cash(controller.enteredTenderMinor!);
      expect(
        repository.cashRequests.single.key,
        isNot(repository.checkouts.single.key),
      );
      expect(repository.cashRequests.single.tender, 1000);
      expect(controller.state.phase, CheckoutPhase.paid);
      expect(controller.state.order!.acceptedPayment!.changeMinor, 675);
      expect(repository.orderReads.length, 2);
      expect(controller.canStartNewOrder, isTrue);
      controller.newOrder();
      expect(controller.state.phase, CheckoutPhase.draft);
      expect(cart.lines, isEmpty);
      cart.add(product());
      repository.currentOrder = orderFixture();
      repository.attempts = [];
      await controller.checkout();
      expect(
        repository.checkouts.last.key,
        isNot(repository.checkouts.first.key),
      );
    },
  );
  test('underpayment rejects locally without a financial mutation', () async {
    await controller.checkout();
    controller.chooseCash();
    controller.setCashInput('3.24');
    await controller.cash(324);
    expect(repository.cashRequests, isEmpty);
    expect(controller.cashInputError, contains('cover'));
    controller.useExactTender();
    expect(controller.enteredTenderMinor, 325);
    expect(controller.cashInputError, isNull);
  });
  test(
    'cash timeout retains key/tender and blocks edits, external and cancellation',
    () async {
      await controller.checkout();
      controller.chooseCash();
      controller.setCashInput('10');
      repository.onCash = (_, _, _) async =>
          throw const CheckoutFailure(CheckoutFailureKind.network);
      await controller.cash(1000);
      final original = repository.cashRequests.single;
      expect(controller.state.phase, CheckoutPhase.requestUncertain);
      expect(controller.retainedTenderMinor, 1000);
      controller.setCashInput('20');
      await controller.cash(2000);
      await controller.external();
      await controller.cancel();
      expect(repository.cashRequests.length, 1);
      expect(repository.externalRequests, isEmpty);
      expect(repository.cancellations, isEmpty);
      expect(controller.cashInput, '10');
      repository.onCash = null;
      await controller.retrySameRequest();
      expect(repository.cashRequests.last, original);
      expect(controller.state.phase, CheckoutPhase.paid);
    },
  );
  test('confirmed POST without paid GET is not success', () async {
    await controller.checkout();
    repository.onCash = (_, _, _) async => paymentFixture();
    await controller.cash(1000);
    expect(controller.state.phase, CheckoutPhase.pendingPayment);
    expect(controller.canChoosePayment, isFalse);
    expect(controller.canStartNewOrder, isFalse);
  });
  test(
    'GET failure after successful cash retries only the read, never cash POST',
    () async {
      await controller.checkout();
      repository.onOrder = (_) async =>
          throw const CheckoutFailure(CheckoutFailureKind.network);
      await controller.cash(1000);
      expect(controller.state.phase, CheckoutPhase.refreshRequired);
      expect(controller.state.retryOperation, isNull);
      repository.onOrder = null;
      await controller.refreshOrder();
      expect(controller.state.phase, CheckoutPhase.paid);
      expect(repository.cashRequests.length, 1);
    },
  );
  test(
    'external unconfigured 503 preserves order/cart and leaves cash available',
    () async {
      await controller.checkout();
      await controller.external();
      expect(
        controller.state.failure!.kind,
        CheckoutFailureKind.providerUnavailable,
      );
      expect(controller.canChoosePayment, isTrue);
      expect(controller.canCancel, isTrue);
      expect(cart.itemCount, 1);
      await controller.cash(1000);
      expect(controller.state.phase, CheckoutPhase.paid);
    },
  );
  test(
    'external timeout retries the same key and never enables another attempt',
    () async {
      await controller.checkout();
      repository.onExternal = (_, _) async =>
          throw const CheckoutFailure(CheckoutFailureKind.network);
      await controller.external();
      final original = repository.externalRequests.single;
      await controller.external();
      await controller.cash(1000);
      await controller.cancel();
      expect(repository.externalRequests.length, 1);
      expect(repository.cashRequests, isEmpty);
      expect(controller.canCancel, isFalse);
      repository.onExternal = (_, _) async {
        final attempt = paymentFixture(
          method: 'external',
          status: 'pending',
          payload: 'SYNTHETIC-QR',
        );
        repository.attempts = [attempt];
        return attempt;
      };
      await controller.retrySameRequest();
      expect(repository.externalRequests.last, original);
      expect(controller.state.payment!.status, PaymentStatus.pending);
      expect(controller.canChoosePayment, isFalse);
      expect(controller.canCheckPayment, isTrue);
    },
  );
  test(
    '503 on retry cannot erase an earlier external transport ambiguity',
    () async {
      await controller.checkout();
      repository.onExternal = (_, _) async =>
          throw const CheckoutFailure(CheckoutFailureKind.network);
      await controller.external();
      repository.onExternal = null;
      await controller.retrySameRequest();
      expect(controller.state.phase, CheckoutPhase.requestUncertain);
      expect(controller.canChoosePayment, isFalse);
      expect(controller.state.retryOperation, CheckoutOperation.external);
    },
  );
  for (final status in ['initiated', 'pending', 'uncertain']) {
    test(
      'backend external $status blocks competing cash/cancellation',
      () async {
        await controller.checkout();
        repository.onExternal = (_, _) async {
          final attempt = paymentFixture(method: 'external', status: status);
          repository.attempts = [attempt];
          return attempt;
        };
        await controller.external();
        await controller.cash(1000);
        await controller.cancel();
        expect(controller.state.payment!.status.name, status);
        expect(controller.canChoosePayment, isFalse);
        expect(repository.cashRequests, isEmpty);
        expect(repository.cancellations, isEmpty);
      },
    );
  }
  for (final status in ['failed', 'expired']) {
    test(
      'terminal external $status without review allows a deliberate new key',
      () async {
        await controller.checkout();
        repository.onExternal = (_, _) async {
          final attempt = paymentFixture(method: 'external', status: status);
          repository.attempts = [attempt];
          return attempt;
        };
        await controller.external();
        expect(controller.canChoosePayment, isTrue);
        await controller.external();
        expect(
          repository.externalRequests.last.key,
          isNot(repository.externalRequests.first.key),
        );
      },
    );
  }
  test(
    'trusted external reconciliation leads to paid only through persisted GET',
    () async {
      await controller.checkout();
      final pending = paymentFixture(
        method: 'external',
        status: 'pending',
        payload: 'SYNTHETIC-QR',
      );
      repository.onExternal = (_, _) async {
        repository.attempts = [pending];
        return pending;
      };
      await controller.external();
      repository.onReconcile = (_, _) async {
        final confirmed = paymentFixture(method: 'external');
        repository.attempts = [confirmed];
        repository.currentOrder = orderFixture(
          status: 'paid',
          accepted: paymentJson(method: 'external'),
        );
        return confirmed;
      };
      await controller.checkPayment();
      expect(controller.state.phase, CheckoutPhase.paid);
      expect(repository.reconciles.single.paymentId, pending.id);
      expect(controller.displayPayload, isNull);
    },
  );
  test(
    'review-required accepted settlement is not a clean paid/New Order state',
    () async {
      await controller.checkout();
      repository.onCash = (_, _, _) async {
        final review = paymentFixture(review: true);
        repository.attempts = [review];
        repository.currentOrder = orderFixture(
          status: 'paid',
          accepted: paymentJson(review: true),
        );
        return review;
      };
      await controller.cash(1000);
      expect(controller.state.phase, CheckoutPhase.review);
      expect(controller.canStartNewOrder, isFalse);
    },
  );
  test(
    'paid GET refresh inspects newly flagged nonaccepted external attempt',
    () async {
      await controller.checkout();
      final failed = paymentFixture(
        method: 'external',
        status: 'failed',
        id: 1,
      );
      repository.attempts = [failed];
      await controller.refreshOrder();
      repository.onCash = (_, _, _) async {
        final cash = paymentFixture(id: 2);
        repository.currentOrder = orderFixture(
          status: 'paid',
          accepted: paymentJson(id: 2),
        );
        repository.attempts = [
          cash,
          paymentFixture(
            method: 'external',
            status: 'confirmed',
            id: 1,
            review: true,
          ),
        ];
        return cash;
      };
      await controller.cash(1000);
      expect(controller.state.phase, CheckoutPhase.review);
      expect(controller.state.payment!.method, PaymentMethod.external);
      expect(controller.canStartNewOrder, isFalse);
      expect(controller.canCheckPayment, isTrue);
    },
  );
  test(
    'more payment pages block clean terminal success until explicitly inspected',
    () async {
      repository.onPayments = (_, page) async =>
          PaymentPage(items: [], currentPage: page, lastPage: 2, total: 101);
      repository.onCreate = (_) async {
        repository.currentOrder = orderFixture(status: 'paid');
        return repository.currentOrder;
      };
      await controller.checkout();
      expect(controller.state.phase, CheckoutPhase.refreshRequired);
      expect(controller.canStartNewOrder, isFalse);
      await controller.loadMoreAttempts();
      expect(controller.state.phase, CheckoutPhase.paid);
      expect(repository.paymentReads.map((request) => request.page), [1, 2]);
    },
  );
  test(
    'pending cancellation is server-authoritative and terminal reset deliberate',
    () async {
      await controller.checkout();
      await controller.cancel();
      expect(controller.state.phase, CheckoutPhase.cancelled);
      expect(repository.cancellations, [orderReference]);
      expect(cart.itemCount, 1);
      controller.newOrder();
      expect(cart.lines, isEmpty);
    },
  );
  test(
    'cancellation timeout keeps the persisted order and retries same reference',
    () async {
      await controller.checkout();
      repository.onCancel = (_) async =>
          throw const CheckoutFailure(CheckoutFailureKind.network);
      await controller.cancel();
      expect(controller.state.phase, CheckoutPhase.requestUncertain);
      expect(controller.canChoosePayment, isFalse);
      repository.onCancel = null;
      await controller.retrySameRequest();
      expect(repository.cancellations, [orderReference, orderReference]);
      expect(controller.state.phase, CheckoutPhase.cancelled);
    },
  );
  test(
    'payment/cancellation 409 reads actual winner instead of guessing',
    () async {
      await controller.checkout();
      repository.onCancel = (_) async {
        repository.currentOrder = orderFixture(status: 'paid');
        repository.attempts = [paymentFixture()];
        throw const CheckoutFailure(
          CheckoutFailureKind.conflict,
          detail: 'Order cannot be safely cancelled.',
        );
      };
      await controller.cancel();
      expect(controller.state.phase, CheckoutPhase.paid);
      expect(controller.state.failure!.kind, CheckoutFailureKind.conflict);
      expect(repository.orderReads.length, 2);
    },
  );
  test(
    '403 remains a feature denial; 401 invalidates the owning session',
    () async {
      var expirations = 0;
      final secured = CheckoutController(
        repository: repository,
        cart: cart,
        onSessionExpired: () => expirations++,
      );
      addTearDown(secured.dispose);
      repository.onCreate = (_) async =>
          throw const CheckoutFailure(CheckoutFailureKind.forbidden);
      await secured.checkout();
      expect(expirations, 0);
      expect(secured.state.failure!.kind, CheckoutFailureKind.forbidden);
      repository.onCreate = (_) async =>
          throw const CheckoutFailure(CheckoutFailureKind.sessionExpired);
      await secured.checkout();
      expect(expirations, 1);
    },
  );
  testWidgets(
    '429 enforces Retry-After without polling or discarding operation identity',
    (tester) async {
      var clock = DateTime.utc(2026, 10, 7);
      final limited = CheckoutController(
        repository: repository,
        cart: cart,
        clock: () => clock,
      );
      repository.onCreate = (_) async => throw const CheckoutFailure(
        CheckoutFailureKind.rateLimited,
        retryAfterSeconds: 2,
      );
      await limited.checkout();
      await limited.checkout();
      expect(repository.checkouts.length, 1);
      clock = clock.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      repository.onCreate = null;
      await limited.checkout();
      expect(repository.checkouts.first.key, repository.checkouts.last.key);
      limited.dispose();
    },
  );
  test('dispose ignores late financial responses', () async {
    final pending = Completer<Order>();
    final disposed = CheckoutController(repository: repository, cart: cart);
    repository.onCreate = (_) => pending.future;
    final request = disposed.checkout();
    disposed.dispose();
    pending.complete(orderFixture());
    await request;
    expect(repository.orderReads, isEmpty);
    expect(disposed.state.order, isNull);
  });
  test(
    'PosController enforces draft locks independently of responsive widgets',
    () async {
      final pos = PosController(
        repository: FakeCatalogRepository(),
        checkoutRepository: repository,
      );
      addTearDown(pos.dispose);
      pos.add(product());
      await pos.checkout!.checkout();
      expect(pos.add(product()), CartLimit.checkoutLocked);
      expect(pos.increment(1), CartLimit.checkoutLocked);
      pos.decrement(1);
      pos.remove(1);
      pos.clearCart();
      expect(pos.cart.itemCount, 1);
      await pos.refresh();
      expect(pos.cart.itemCount, 1);
    },
  );
  test(
    'confirmed return followed by failed attempt-list read cannot show success',
    () async {
      await controller.checkout();
      repository.onPayments = (_, _) async =>
          throw const CheckoutFailure(CheckoutFailureKind.network);
      await controller.cash(1000);
      expect(controller.state.phase, CheckoutPhase.refreshRequired);
      expect(controller.canStartNewOrder, isFalse);
    },
  );
}
