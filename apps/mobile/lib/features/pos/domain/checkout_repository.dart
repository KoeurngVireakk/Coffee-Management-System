import 'checkout_intent.dart';
import 'order.dart';
import 'payment.dart';

abstract interface class CheckoutRepository {
  Future<Order> createOrder(CheckoutIntent intent);
  Future<Order> order(String reference);
  Future<Payment> cash(
    String reference, {
    required String key,
    required int tenderMinor,
  });
  Future<Payment> external(String reference, {required String key});
  Future<PaymentPage> payments(String reference, {int page = 1});
  Future<Payment> reconcile(String reference, int paymentId);
  Future<Order> cancel(String reference);
}

enum CheckoutFailureKind {
  sessionExpired,
  forbidden,
  notFound,
  conflict,
  validation,
  rateLimited,
  providerUnavailable,
  network,
  server,
  invalidResponse,
}

class CheckoutFailure implements Exception {
  const CheckoutFailure(
    this.kind, {
    this.detail,
    this.errors = const {},
    this.retryAfterSeconds,
  });
  final CheckoutFailureKind kind;
  final String? detail;
  final Map<String, List<String>> errors;
  final int? retryAfterSeconds;
  bool get mayHaveCommitted =>
      kind == CheckoutFailureKind.network ||
      kind == CheckoutFailureKind.server ||
      kind == CheckoutFailureKind.invalidResponse;
  String? fieldMessage(String field) => errors[field]?.firstOrNull;
  String get message => switch (kind) {
    CheckoutFailureKind.sessionExpired =>
      'Your session has expired. Please sign in again.',
    CheckoutFailureKind.forbidden =>
      'You do not have permission for this action. Contact your manager.',
    CheckoutFailureKind.notFound =>
      'This order or payment is unavailable to your account.',
    CheckoutFailureKind.conflict =>
      detail ?? 'This order cannot be changed now. Refresh its status.',
    CheckoutFailureKind.validation =>
      fieldMessage('items') ??
          fieldMessage('tender_minor') ??
          fieldMessage('idempotency_key') ??
          'The request was rejected. Review the order and try again.',
    CheckoutFailureKind.rateLimited =>
      'Too many requests. Please wait before retrying.',
    CheckoutFailureKind.providerUnavailable =>
      'External payment is currently unavailable. Use cash or try again later.',
    CheckoutFailureKind.network =>
      'The request outcome is unknown. Check your connection and retry the same request.',
    CheckoutFailureKind.server =>
      'The service could not complete the response. Retry the same request safely.',
    CheckoutFailureKind.invalidResponse =>
      'The response could not be read safely. Verify the existing order before continuing.',
  };
}
