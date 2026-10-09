import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/cart.dart';
import '../domain/checkout_intent.dart';
import '../domain/checkout_repository.dart';
import '../domain/exact_money.dart';
import '../domain/order.dart';
import '../domain/payment.dart';

enum CheckoutPhase {
  draft,
  submitting,
  verifyingOrder,
  pendingPayment,
  cashEntry,
  requestUncertain,
  refreshRequired,
  paid,
  cancelled,
  expired,
  review,
}

enum CheckoutOperation { checkout, cash, external, cancel, reconcile }

/// Immutable identity for a submitted mutation. Never reconstructed on retry.
class _Mutation {
  const _Mutation(
    this.operation, {
    this.key,
    this.tenderMinor,
    this.paymentId,
    this.intent,
  });
  final CheckoutOperation operation;
  final String? key;
  final int? tenderMinor;
  final int? paymentId;
  final CheckoutIntent? intent;
}

class CheckoutState {
  const CheckoutState({
    this.phase = CheckoutPhase.draft,
    this.order,
    this.payment,
    this.failure,
    this.operation,
    this.retryOperation,
    this.retryAt,
  });
  final CheckoutPhase phase;
  final Order? order;
  final Payment? payment;
  final CheckoutFailure? failure;
  final CheckoutOperation? operation;
  final CheckoutOperation? retryOperation;
  final DateTime? retryAt;
  bool get busy =>
      phase == CheckoutPhase.submitting ||
      phase == CheckoutPhase.verifyingOrder;
}

/// Session-owned financial workflow. Catalog/UI lifetime never owns requests.
class CheckoutController extends ChangeNotifier {
  CheckoutController({
    required this.repository,
    required this.cart,
    this.onSessionExpired,
    String Function()? keyGenerator,
    DateTime Function()? clock,
  }) : _keyGenerator = keyGenerator ?? OperationKey.generate,
       _clock = clock ?? DateTime.now;
  final CheckoutRepository repository;
  final Cart cart;
  final VoidCallback? onSessionExpired;
  final String Function() _keyGenerator;
  final DateTime Function() _clock;
  CheckoutState _state = const CheckoutState();
  CheckoutState get state => _state;
  Order? _order;
  CheckoutIntent? _intent;
  _Mutation? _unresolved;
  _Mutation? _cashRequest;
  _Mutation? _externalRequest;
  final Map<int, Payment> _payments = {};
  final Set<String> _usedKeys = {};
  Payment? _latestPayment;
  PaymentPage? _paymentPage;
  String _cashInput = '';
  String get cashInput => _cashInput;
  int? get enteredTenderMinor {
    try {
      return ExactMoney.cashEntry(_cashInput);
    } on FormatException {
      return null;
    }
  }

  String? get cashInputError {
    if (_cashInput.trim().isEmpty) {
      return state.failure?.fieldMessage('tender_minor');
    }
    final tender = enteredTenderMinor;
    if (tender == null) {
      return 'Enter USD dollars with at most two decimal places.';
    }
    if (_order != null && tender < _order!.totalMinor) {
      return 'Cash received must cover the order total.';
    }
    return state.failure?.fieldMessage('tender_minor');
  }

  DateTime? _retryAt;
  Timer? _cooldownTimer;
  Timer? _displayTimer;
  bool _disposed = false;
  int _generation = 0;

  DateTime get now => _clock().toUtc();
  bool get coolingDown => _retryAt != null && now.isBefore(_retryAt!);
  bool get canEditCart => state.phase == CheckoutPhase.draft;
  bool get canCheckout => canEditCart && cart.distinctCount > 0 && !coolingDown;
  bool get hasMoreAttempts =>
      _paymentPage != null &&
      _paymentPage!.currentPage < _paymentPage!.lastPage;
  bool get canLoadMoreAttempts =>
      hasMoreAttempts &&
      _paymentPage!.currentPage < 10000 &&
      !state.busy &&
      !coolingDown;
  bool get _knownEligible =>
      _order?.status == OrderStatus.pendingPayment &&
      _paymentPage != null &&
      !hasMoreAttempts &&
      !_payments.values.any((payment) => payment.blocksSettlement) &&
      _unresolved == null;
  bool get canChoosePayment =>
      !state.busy &&
      !coolingDown &&
      _knownEligible &&
      (state.phase == CheckoutPhase.pendingPayment ||
          state.phase == CheckoutPhase.cashEntry);
  bool get canCancel => canChoosePayment;
  bool get canStartNewOrder =>
      !state.busy &&
      (state.phase == CheckoutPhase.paid ||
          state.phase == CheckoutPhase.cancelled ||
          state.phase == CheckoutPhase.expired);
  bool get canCheckPayment =>
      !state.busy &&
      !coolingDown &&
      state.payment?.method == PaymentMethod.external &&
      _order != null;
  int? get retainedTenderMinor =>
      _unresolved?.operation == CheckoutOperation.cash
      ? _unresolved!.tenderMinor
      : null;
  int? get previewTotalMinor => _intent?.previewTotalMinor;
  String? get displayPayload => state.payment?.displayPayload(now);

  void _publish(
    CheckoutPhase phase, {
    CheckoutFailure? failure,
    CheckoutOperation? operation,
  }) {
    if (_disposed) return;
    final blocked =
        _payments.values.where((payment) => payment.blocksSettlement).toList()
          ..sort((a, b) {
            if (a.reconciliationRequired != b.reconciliationRequired) {
              return a.reconciliationRequired ? -1 : 1;
            }
            return b.id.compareTo(a.id);
          });
    final payment =
        blocked.firstOrNull ?? _latestPayment ?? _order?.acceptedPayment;
    _state = CheckoutState(
      phase: phase,
      order: _order,
      payment: payment,
      failure: failure,
      operation: operation,
      retryOperation: _unresolved?.operation,
      retryAt: _retryAt,
    );
    _displayTimer?.cancel();
    final expires = payment?.expiresAt;
    if (payment?.displayPayload(now) != null && expires != null) {
      _displayTimer = Timer(expires.difference(now), () {
        if (!_disposed) notifyListeners();
      });
    }
    notifyListeners();
  }

  String? _newKey() {
    try {
      for (var tries = 0; tries < 3; tries++) {
        final key = _keyGenerator();
        OperationKey.validate(key);
        if (_usedKeys.add(key)) return key;
      }
    } on UnsupportedError {
      // Never replace unavailable secure randomness with a weak identifier.
    } on ArgumentError {
      // Invalid injected generators must also fail closed before HTTP.
    }
    _publish(
      state.phase,
      failure: const CheckoutFailure(
        CheckoutFailureKind.validation,
        errors: {
          'idempotency_key': [
            'A secure request identity could not be created. Please try later.',
          ],
        },
      ),
    );
    return null;
  }

  Future<void> checkout() async {
    if (!canCheckout) return;
    if (_intent == null || !_intent!.matchesCart(cart)) {
      final key = _newKey();
      if (key == null) return;
      _intent = CheckoutIntent(
        key: key,
        items: [
          for (final line in cart.lines)
            CheckoutItem(productId: line.product.id, quantity: line.quantity),
        ],
        previewTotalMinor: cart.subtotalMinor,
      );
    }
    await _submit(_Mutation(CheckoutOperation.checkout, intent: _intent));
  }

  void chooseCash() {
    if (canChoosePayment) _publish(CheckoutPhase.cashEntry);
  }

  void setCashInput(String value) {
    if (!canChoosePayment || state.phase != CheckoutPhase.cashEntry) return;
    _cashInput = value;
    _publish(CheckoutPhase.cashEntry);
  }

  void useExactTender() {
    if (canChoosePayment && _order != null) {
      setCashInput(ExactMoney.entryFor(_order!.totalMinor));
    }
  }

  void chooseMethods() {
    if (canChoosePayment) _publish(CheckoutPhase.pendingPayment);
  }

  Future<void> cash(int tenderMinor) async {
    if (!canChoosePayment || _order == null) return;
    if (tenderMinor < _order!.totalMinor ||
        tenderMinor > ExactMoney.maxTender) {
      _publish(
        CheckoutPhase.cashEntry,
        failure: const CheckoutFailure(
          CheckoutFailureKind.validation,
          errors: {
            'tender_minor': [
              'Cash received must cover the order total within supported bounds.',
            ],
          },
        ),
      );
      return;
    }
    if (_cashRequest == null || _cashRequest!.tenderMinor != tenderMinor) {
      final key = _newKey();
      if (key == null) return;
      _cashRequest = _Mutation(
        CheckoutOperation.cash,
        key: key,
        tenderMinor: tenderMinor,
      );
    }
    await _submit(_cashRequest!);
  }

  Future<void> external() async {
    if (!canChoosePayment) return;
    if (_externalRequest == null) {
      final key = _newKey();
      if (key == null) return;
      _externalRequest = _Mutation(CheckoutOperation.external, key: key);
    }
    await _submit(_externalRequest!);
  }

  Future<void> cancel() async {
    if (!canCancel) return;
    await _submit(const _Mutation(CheckoutOperation.cancel));
  }

  Future<void> checkPayment() async {
    if (!canCheckPayment) return;
    await _submit(
      _Mutation(CheckoutOperation.reconcile, paymentId: state.payment!.id),
    );
  }

  Future<void> retrySameRequest() async {
    if (_disposed || state.busy || coolingDown || _unresolved == null) return;
    await _submit(_unresolved!);
  }

  Future<void> _submit(_Mutation request) async {
    if (_disposed || state.busy || coolingDown) return;
    final generation = ++_generation;
    final existingUncertainty = _unresolved;
    _publish(CheckoutPhase.submitting, operation: request.operation);
    try {
      switch (request.operation) {
        case CheckoutOperation.checkout:
          final order = await repository.createOrder(request.intent!);
          if (!_live(generation)) return;
          _adoptOrder(order);
        case CheckoutOperation.cash:
          final payment = await repository.cash(
            _order!.reference,
            key: request.key!,
            tenderMinor: request.tenderMinor!,
          );
          if (!_live(generation)) return;
          _adoptPayment(payment);
        case CheckoutOperation.external:
          final payment = await repository.external(
            _order!.reference,
            key: request.key!,
          );
          if (!_live(generation)) return;
          _adoptPayment(payment);
        case CheckoutOperation.cancel:
          final order = await repository.cancel(_order!.reference);
          if (!_live(generation)) return;
          _adoptOrder(order);
        case CheckoutOperation.reconcile:
          final payment = await repository.reconcile(
            _order!.reference,
            request.paymentId!,
          );
          if (!_live(generation)) return;
          _adoptPayment(payment);
      }
      if (_unresolved == request) _unresolved = null;
      // A terminal order can still have a nonaccepted attempt requiring review.
      await _refresh(generation);
    } on CheckoutFailure catch (failure) {
      if (!_live(generation)) return;
      if (failure.kind == CheckoutFailureKind.sessionExpired) {
        onSessionExpired?.call();
        return;
      }
      _applyCooldown(failure);
      final unavailableBeforeIntent =
          request.operation == CheckoutOperation.external &&
          failure.kind == CheckoutFailureKind.providerUnavailable &&
          existingUncertainty == null;
      if (failure.mayHaveCommitted ||
          failure.kind == CheckoutFailureKind.providerUnavailable &&
              !unavailableBeforeIntent) {
        _unresolved = existingUncertainty ?? request;
      }
      if (failure.kind == CheckoutFailureKind.conflict && _order != null) {
        await _refresh(generation, failure: failure);
      } else if (_unresolved != null) {
        _publish(CheckoutPhase.requestUncertain, failure: failure);
      } else if (_order == null) {
        _publish(CheckoutPhase.draft, failure: failure);
      } else {
        _publish(
          request.operation == CheckoutOperation.cash
              ? CheckoutPhase.cashEntry
              : CheckoutPhase.pendingPayment,
          failure: failure,
        );
      }
    }
  }

  bool _live(int generation) => !_disposed && generation == _generation;

  void _adoptPayment(Payment payment) {
    if (_order == null || payment.expectedAmountMinor != _order!.totalMinor) {
      throw const CheckoutFailure(CheckoutFailureKind.invalidResponse);
    }
    final previous = _payments[payment.id];
    if (previous != null &&
        (previous.method != payment.method ||
            previous.expectedAmountMinor != payment.expectedAmountMinor ||
            previous.tenderMinor != payment.tenderMinor ||
            previous.changeMinor != payment.changeMinor ||
            previous.provider != payment.provider)) {
      throw const CheckoutFailure(CheckoutFailureKind.invalidResponse);
    }
    _payments[payment.id] = payment;
    if (_latestPayment == null || payment.id >= _latestPayment!.id) {
      _latestPayment = payment;
    }
    if (payment.method == PaymentMethod.external && !payment.blocksSettlement) {
      _externalRequest = null;
    }
  }

  void _adoptOrder(Order order) {
    final previous = _order;
    if (previous != null &&
        (order.reference != previous.reference ||
            order.totalMinor != previous.totalMinor ||
            order.creatorId != previous.creatorId ||
            order.inventoryTracked != previous.inventoryTracked ||
            order.items.length != previous.items.length ||
            List.generate(order.items.length, (i) {
              final before = previous.items[i], after = order.items[i];
              return before.productId != after.productId ||
                  before.quantity != after.quantity ||
                  before.unitPriceMinor != after.unitPriceMinor ||
                  before.productName != after.productName ||
                  before.productSku != after.productSku;
            }).contains(true) ||
            previous.status != OrderStatus.pendingPayment &&
                order.status != previous.status)) {
      throw const CheckoutFailure(CheckoutFailureKind.invalidResponse);
    }
    _order = order;
    if (order.acceptedPayment != null) _adoptPayment(order.acceptedPayment!);
  }

  Future<void> refreshOrder() async {
    if (_disposed || state.busy || coolingDown || _order == null) return;
    await _refresh(++_generation);
  }

  Future<void> _refresh(int generation, {CheckoutFailure? failure}) async {
    _publish(CheckoutPhase.verifyingOrder, failure: failure);
    try {
      final order = await repository.order(_order!.reference);
      if (!_live(generation)) return;
      _adoptOrder(order);
      final page = await repository.payments(order.reference);
      if (!_live(generation)) return;
      for (final payment in page.items) {
        _adoptPayment(payment);
      }
      _paymentPage = page;
      _settledView(failure: failure);
    } on CheckoutFailure catch (error) {
      if (!_live(generation)) return;
      if (error.kind == CheckoutFailureKind.sessionExpired) {
        onSessionExpired?.call();
        return;
      }
      _applyCooldown(error);
      _publish(CheckoutPhase.refreshRequired, failure: error);
    }
  }

  Future<void> loadMoreAttempts() async {
    if (!canLoadMoreAttempts) return;
    final generation = ++_generation;
    _publish(CheckoutPhase.verifyingOrder);
    try {
      final page = await repository.payments(
        _order!.reference,
        page: _paymentPage!.currentPage + 1,
      );
      if (!_live(generation)) return;
      for (final payment in page.items) {
        _adoptPayment(payment);
      }
      _paymentPage = page;
      _settledView();
    } on CheckoutFailure catch (failure) {
      if (!_live(generation)) return;
      if (failure.kind == CheckoutFailureKind.sessionExpired) {
        onSessionExpired?.call();
        return;
      }
      _applyCooldown(failure);
      _publish(CheckoutPhase.refreshRequired, failure: failure);
    }
  }

  void _settledView({CheckoutFailure? failure}) {
    if (_payments.values.any((payment) => payment.reconciliationRequired)) {
      _publish(CheckoutPhase.review, failure: failure);
      return;
    }
    if (hasMoreAttempts) {
      _publish(CheckoutPhase.refreshRequired, failure: failure);
      return;
    }
    switch (_order!.status) {
      case OrderStatus.paid:
        _unresolved = null;
        _publish(CheckoutPhase.paid, failure: failure);
      case OrderStatus.cancelled:
        _unresolved = null;
        _publish(CheckoutPhase.cancelled, failure: failure);
      case OrderStatus.expired:
        _unresolved = null;
        _publish(CheckoutPhase.expired, failure: failure);
      case OrderStatus.pendingPayment:
        _publish(
          _unresolved == null
              ? CheckoutPhase.pendingPayment
              : CheckoutPhase.requestUncertain,
          failure: failure,
        );
    }
  }

  void _applyCooldown(CheckoutFailure failure) {
    if (failure.kind != CheckoutFailureKind.rateLimited) return;
    final seconds = (failure.retryAfterSeconds ?? 30).clamp(1, 3600);
    _retryAt = now.add(Duration(seconds: seconds));
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(Duration(seconds: seconds), () {
      if (!_disposed) notifyListeners();
    });
  }

  void newOrder() {
    if (!canStartNewOrder) return;
    _generation++;
    _order = null;
    _intent = null;
    _unresolved = null;
    _cashRequest = null;
    _externalRequest = null;
    _payments.clear();
    _latestPayment = null;
    _paymentPage = null;
    _cashInput = '';
    cart.clear();
    _publish(CheckoutPhase.draft);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cooldownTimer?.cancel();
    _displayTimer?.cancel();
    super.dispose();
  }
}
