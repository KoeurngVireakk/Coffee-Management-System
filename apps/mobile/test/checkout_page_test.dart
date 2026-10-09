import 'dart:async';
import 'package:coffee_management_mobile/features/pos/domain/checkout_repository.dart';
import 'package:coffee_management_mobile/features/pos/domain/cart.dart';
import 'package:coffee_management_mobile/features/pos/domain/order.dart';
import 'package:coffee_management_mobile/features/pos/presentation/checkout_controller.dart';
import 'package:coffee_management_mobile/features/pos/presentation/checkout_panel.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_controller.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_cart_panel.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_page.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_product_card.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'checkout_test_support.dart';
import 'pos_test_support.dart';

void main() {
  late FakeCheckoutRepository repository;
  late PosController pos;
  setUp(() {
    repository = FakeCheckoutRepository();
    pos = PosController(
      repository: FakeCatalogRepository(),
      checkoutRepository: repository,
    );
  });
  tearDown(() => pos.dispose());
  Future<void> pumpPos(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool dark = false,
    double scale = 1,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.buildDarkTheme() : AppTheme.buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: Scaffold(body: PosPage(controller: pos)),
      ),
    );
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(label),
        160,
        maxScrolls: 50,
        scrollable: find
            .descendant(
              of: find
                  .descendant(
                    of: find.byType(PosCartPanel).last,
                    matching: find.byType(ListView),
                  )
                  .first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    final finder = find.text(label).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> checkout(WidgetTester tester) async {
    pos.add(product());
    await tester.pump();
    if (find.byKey(const ValueKey('open-cart')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('open-cart')));
      await tester.pumpAndSettle();
    }
    await tap(tester, 'Checkout');
  }

  Finder cashField() => find.widgetWithText(TextField, 'Cash received in USD');
  testWidgets(
    'desktop density retains 48dp payment controls and a labeled order reference',
    (tester) async {
      final semantics = tester.ensureSemantics();
      pos.add(product());
      await pos.checkout!.checkout();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme().copyWith(
            visualDensity: VisualDensity.compact,
          ),
          home: Scaffold(body: CheckoutPanel(controller: pos.checkout!)),
        ),
      );
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Cash')).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .getSize(find.widgetWithText(OutlinedButton, 'External payment'))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        find.bySemanticsLabel('Order reference $orderReference'),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );
  testWidgets(
    'cash 429 disables edits and resumes with displayed and submitted tender equal',
    (tester) async {
      var clock = DateTime.utc(2026, 10, 7);
      final limited = CheckoutController(
        repository: repository,
        cart: Cart()..add(product()),
        clock: () => clock,
      );
      await limited.checkout();
      limited.chooseCash();
      limited.setCashInput('10');
      repository.onCash = (_, _, _) async => throw const CheckoutFailure(
        CheckoutFailureKind.rateLimited,
        retryAfterSeconds: 2,
      );
      await limited.cash(1000);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(body: CheckoutPanel(controller: limited)),
        ),
      );
      expect(tester.widget<TextField>(cashField()).enabled, isFalse);
      expect(tester.widget<TextField>(cashField()).controller!.text, '10');
      expect(limited.cashInput, '10');
      clock = clock.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<TextField>(cashField()).enabled, isTrue);
      repository.onCash = null;
      await tester.enterText(cashField(), '20');
      await tester.pump();
      await tap(tester, 'Confirm cash payment');
      expect(repository.cashRequests.last.tender, 2000);
      limited.dispose();
    },
  );

  testWidgets(
    'editing an open sheet after resizing synchronizes the desktop tender',
    (tester) async {
      await pumpPos(tester);
      await checkout(tester);
      await tap(tester, 'Cash');
      await tester.enterText(cashField(), '10');
      await tester.pump();
      await pumpPos(tester, size: const Size(1440, 900));
      final topField = cashField().last;
      await tester.enterText(topField, '20');
      await tester.pump();
      await tester.tap(find.byTooltip('Close order panel'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(cashField()).controller!.text, '20');
      expect(pos.checkout!.cashInput, '20');
      await tap(tester, 'Confirm cash payment');
      expect(repository.cashRequests.single.tender, 2000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile cart creates pending order, cash settles, New Order resets deliberately',
    (tester) async {
      await pumpPos(tester);
      await checkout(tester);
      expect(find.text('Pending Order'), findsOneWidget);
      expect(find.text(orderReference), findsOneWidget);
      expect(pos.cart.itemCount, 1);
      await tap(tester, 'Cash');
      await tester.enterText(cashField(), '10.50');
      await tester.pump();
      expect(find.text(r'Change preview: $7.25 USD'), findsOneWidget);
      await tap(tester, 'Confirm cash payment');
      expect(find.text('Payment successful'), findsOneWidget);
      expect(find.text(r'Cash received: $10.50 USD'), findsOneWidget);
      expect(find.text(r'Change: $7.25 USD'), findsOneWidget);
      expect(repository.orderReads.length, 2);
      await tap(tester, 'New Order');
      expect(pos.cart.itemCount, 0);
      expect(find.text('Your order is empty'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'server price replaces preview, including compact persistent summary',
    (tester) async {
      repository.serverUnitMinor = 450;
      await pumpPos(tester);
      await checkout(tester);
      expect(find.text(r'$4.50'), findsOneWidget);
      expect(find.textContaining('Prices changed'), findsOneWidget);
      await tester.tap(find.byTooltip('Close order panel'));
      await tester.pumpAndSettle();
      expect(find.text(r'$4.50 USD'), findsOneWidget);
      expect(find.text('View order · 1 items'), findsOneWidget);
    },
  );
  testWidgets('loading prevents duplicate checkout and retains preview', (
    tester,
  ) async {
    final pending = Completer<Order>();
    repository.onCreate = (_) => pending.future;
    await pumpPos(tester, size: const Size(1440, 900));
    pos.add(product());
    await tester.pump();
    await tester.tap(find.text('Checkout'));
    await tester.pump();
    expect(find.text('Creating order…'), findsOneWidget);
    expect(find.text('Order preview · USD'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);
    expect(repository.checkouts.length, 1);
    pending.complete(orderFixture());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'checkout timeout exposes explicit same-key retry and preserves items',
    (tester) async {
      repository.onCreate = (_) async =>
          throw const CheckoutFailure(CheckoutFailureKind.network);
      await pumpPos(tester);
      await checkout(tester);
      expect(find.text('Request outcome uncertain'), findsOneWidget);
      expect(find.text('Retry checkout'), findsOneWidget);
      expect(find.text('1 × Cappuccino'), findsOneWidget);
      repository.onCreate = null;
      await tap(tester, 'Retry checkout');
      expect(repository.checkouts.first.key, repository.checkouts.last.key);
      expect(find.text('Pending Order'), findsOneWidget);
    },
  );
  testWidgets(
    'external default 503 explains availability and cash remains usable',
    (tester) async {
      await pumpPos(tester);
      await checkout(tester);
      await tap(tester, 'External payment');
      expect(
        find.textContaining('External payment is currently unavailable'),
        findsOneWidget,
      );
      expect(find.text('Cash'), findsOneWidget);
      expect(pos.cart.itemCount, 1);
      await tap(tester, 'Cash');
      await tap(tester, 'Exact amount');
      expect(pos.checkout!.enteredTenderMinor, 325);
      await tap(tester, 'Confirm cash payment');
      expect(find.text('Payment successful'), findsOneWidget);
    },
  );
  for (final status in [
    'initiated',
    'pending',
    'uncertain',
    'failed',
    'expired',
  ]) {
    testWidgets(
      'external $status presents backend meaning without a paid claim',
      (tester) async {
        await pumpPos(tester);
        await checkout(tester);
        repository.onExternal = (_, _) async {
          final payment = paymentFixture(
            method: 'external',
            status: status,
            payload: status == 'pending' ? 'SYNTHETIC-QR-DISPLAY' : null,
          );
          repository.attempts = [payment];
          return payment;
        };
        await tap(tester, 'External payment');
        expect(
          find.text(status[0].toUpperCase() + status.substring(1)),
          findsWidgets,
        );
        expect(find.text('Payment successful'), findsNothing);
        if (status == 'pending') {
          expect(find.text('SYNTHETIC-QR-DISPLAY'), findsOneWidget);
          expect(
            find.textContaining('does not mean the order is paid'),
            findsOneWidget,
          );
        }
        if (status == 'expired') {
          expect(find.text('SYNTHETIC-QR-DISPLAY'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'external check status uses trusted reconcile then persisted paid order',
    (tester) async {
      await pumpPos(tester);
      await checkout(tester);
      repository.onExternal = (_, _) async {
        final pending = paymentFixture(
          method: 'external',
          status: 'pending',
          payload: 'SYNTHETIC-QR',
        );
        repository.attempts = [pending];
        return pending;
      };
      await tap(tester, 'External payment');
      repository.onReconcile = (_, _) async {
        final confirmed = paymentFixture(method: 'external');
        repository.attempts = [confirmed];
        repository.currentOrder = orderFixture(
          status: 'paid',
          accepted: paymentJson(method: 'external'),
        );
        return confirmed;
      };
      await tap(tester, 'Check payment status');
      expect(find.text('Payment successful'), findsOneWidget);
      expect(find.text('Paid by External payment'), findsOneWidget);
      expect(find.text('SYNTHETIC-QR'), findsNothing);
    },
  );
  testWidgets(
    'review warning suppresses success and new transaction controls',
    (tester) async {
      await pumpPos(tester);
      await checkout(tester);
      repository.onExternal = (_, _) async {
        final review = paymentFixture(
          method: 'external',
          status: 'uncertain',
          review: true,
        );
        repository.attempts = [review];
        return review;
      };
      await tap(tester, 'External payment');
      expect(find.text('Payment requires review'), findsOneWidget);
      expect(find.text('Payment successful'), findsNothing);
      expect(find.text('New Order'), findsNothing);
      expect(find.text('Cash'), findsNothing);
      expect(find.textContaining('Contact your manager'), findsOneWidget);
    },
  );
  testWidgets(
    'cancellation requires deliberate confirmation and shows persisted outcome',
    (tester) async {
      await pumpPos(tester);
      await checkout(tester);
      await tap(tester, 'Cancel pending order');
      expect(repository.cancellations, isEmpty);
      await tap(tester, 'Keep order');
      expect(repository.cancellations, isEmpty);
      await tap(tester, 'Cancel pending order');
      await tap(tester, 'Cancel order');
      expect(find.text('Order cancelled'), findsOneWidget);
      expect(repository.cancellations.length, 1);
      expect(pos.cart.itemCount, 1);
    },
  );
  testWidgets(
    'cash keyboard inset leaves field and confirm action reachable above keyboard',
    (tester) async {
      await pumpPos(tester);
      await checkout(tester);
      await tap(tester, 'Cash');
      await pumpPos(tester, keyboard: 320);
      await tester.ensureVisible(cashField());
      await tester.enterText(cashField(), '10');
      await tester.pump();
      final button = find.text('Confirm cash payment');
      await tester.ensureVisible(button);
      await tester.pump();
      expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(844 - 320));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(pos.checkout!.state.phase, CheckoutPhase.paid);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('invalid cash copy wraps at 320px and 2x text', (tester) async {
    await pumpPos(tester, size: const Size(320, 720), scale: 2);
    await checkout(tester);
    await tap(tester, 'Cash');
    await tester.ensureVisible(cashField());
    await tester.enterText(cashField(), '10.001');
    await tester.pump();
    expect(
      find.text('Enter USD dollars with at most two decimal places.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(cashField()).decoration!.errorMaxLines,
      greaterThanOrEqualTo(3),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'cash Enter and labeled 48dp controls work with keyboard and semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPos(tester, size: const Size(1440, 900));
      await checkout(tester);
      await tap(tester, 'Cash');
      expect(find.bySemanticsLabel('Cash received in USD'), findsOneWidget);
      await tester.enterText(cashField(), '10');
      await tester.pump();
      final button = find.widgetWithText(FilledButton, 'Confirm cash payment');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(pos.checkout!.state.phase, CheckoutPhase.paid);
      semantics.dispose();
    },
  );
  testWidgets(
    'cash input and pending operation survive sheet closure, resize and theme',
    (tester) async {
      await pumpPos(tester);
      await checkout(tester);
      await tap(tester, 'Cash');
      await tester.enterText(cashField(), '10.50');
      await tester.pump();
      await tester.tap(find.byTooltip('Close order panel'));
      await tester.pumpAndSettle();
      await pumpPos(tester, size: const Size(1440, 900), dark: true);
      expect(tester.widget<TextField>(cashField()).controller!.text, '10.50');
      expect(pos.checkout!.state.phase, CheckoutPhase.cashEntry);
      expect(repository.checkouts.length, 1);
      final card = tester.widget<PosProductCard>(find.byType(PosProductCard));
      expect(card.onAdd, isNull);
    },
  );
  for (final size in [
    const Size(320, 720),
    const Size(768, 1024),
    const Size(1440, 900),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Phase 5 draft and cash flow fit $size ${dark ? 'dark' : 'light'} at 2x text',
        (tester) async {
          await pumpPos(tester, size: size, dark: dark, scale: 2);
          await checkout(tester);
          expect(tester.takeException(), isNull);
          await tap(tester, 'Cash');
          await tester.ensureVisible(cashField());
          await tester.enterText(cashField(), 'bad');
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
