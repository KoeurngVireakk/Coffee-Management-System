import 'package:coffee_management_mobile/features/pos/data/checkout_dto.dart';
import 'package:coffee_management_mobile/features/pos/domain/checkout_intent.dart';
import 'package:coffee_management_mobile/features/pos/domain/checkout_repository.dart';
import 'package:coffee_management_mobile/features/pos/domain/order.dart';
import 'package:coffee_management_mobile/features/pos/domain/payment.dart';

const orderReference = 'ORD-01K6WY00000000000000000000';
const fixtureTimestamp = '2026-10-07T01:00:00+00:00';

Map<String, dynamic> paymentJson({
  String method = 'cash',
  String status = 'confirmed',
  int id = 1,
  int amount = 325,
  int tender = 1000,
  bool review = false,
  String? payload,
  String? expires,
}) => {
  'id': id,
  'method': method,
  'status': status,
  'expected_amount_minor': '$amount',
  'currency': 'USD',
  'tender_minor': method == 'cash' ? '$tender' : null,
  'change_minor': method == 'cash' ? '${tender - amount}' : null,
  'provider': method == 'external' ? 'synthetic' : null,
  'reconciliation_required': review,
  'expires_at': expires,
  'verified_at': status == 'confirmed' ? fixtureTimestamp : null,
  'created_at': fixtureTimestamp,
  'qr_payload': payload,
};
Map<String, dynamic> orderItemJson({
  int id = 1,
  int quantity = 1,
  int unit = 325,
  int line = 1,
}) => {
  'line_number': line,
  'product_id': id,
  'product_name': id == 1 ? 'Cappuccino' : 'Tea $id',
  'product_sku': 'COFFEE-$id',
  'unit_price_minor': '$unit',
  'quantity': quantity,
  'subtotal_minor': '${unit * quantity}',
  'discount_minor': '0',
  'tax_minor': '0',
  'line_total_minor': '${unit * quantity}',
};
Map<String, dynamic> orderJson({
  String status = 'pending_payment',
  int unit = 325,
  List<CheckoutItem>? intentItems,
  Map<String, dynamic>? accepted,
  bool tracked = false,
}) {
  final items = intentItems ?? [CheckoutItem(productId: 1, quantity: 1)];
  final total = items.fold(0, (sum, item) => sum + unit * item.quantity);
  return {
    'public_reference': orderReference,
    'status': status,
    'currency': 'USD',
    'subtotal_minor': '$total',
    'discount_minor': '0',
    'tax_minor': '0',
    'total_minor': '$total',
    'inventory_tracked': tracked,
    'created_at': fixtureTimestamp,
    'creator': {'id': 1, 'name': 'Synthetic cashier'},
    'items': [
      for (var i = 0; i < items.length; i++)
        orderItemJson(
          id: items[i].productId,
          quantity: items[i].quantity,
          unit: unit,
          line: i + 1,
        ),
    ],
    if (status == 'paid')
      'accepted_payment': accepted ?? paymentJson(amount: total),
    if (status == 'paid') 'paid_at': fixtureTimestamp,
  };
}

Order orderFixture({
  String status = 'pending_payment',
  int unit = 325,
  List<CheckoutItem>? items,
  Map<String, dynamic>? accepted,
}) => CheckoutDto.order(
  orderJson(status: status, unit: unit, intentItems: items, accepted: accepted),
);
Payment paymentFixture({
  String method = 'cash',
  String status = 'confirmed',
  int id = 1,
  int amount = 325,
  int tender = 1000,
  bool review = false,
  String? payload,
  String? expires,
}) => CheckoutDto.payment(
  paymentJson(
    method: method,
    status: status,
    id: id,
    amount: amount,
    tender: tender,
    review: review,
    payload: payload,
    expires: expires,
  ),
);

class FakeCheckoutRepository implements CheckoutRepository {
  Order currentOrder = orderFixture();
  List<Payment> attempts = [];
  int serverUnitMinor = 325;
  Future<Order> Function(CheckoutIntent)? onCreate;
  Future<Order> Function(String)? onOrder;
  Future<Payment> Function(String, String, int)? onCash;
  Future<Payment> Function(String, String)? onExternal;
  Future<PaymentPage> Function(String, int)? onPayments;
  Future<Payment> Function(String, int)? onReconcile;
  Future<Order> Function(String)? onCancel;
  final checkouts = <CheckoutIntent>[];
  final cashRequests = <({String reference, String key, int tender})>[];
  final externalRequests = <({String reference, String key})>[];
  final orderReads = <String>[];
  final paymentReads = <({String reference, int page})>[];
  final reconciles = <({String reference, int paymentId})>[];
  final cancellations = <String>[];

  @override
  Future<Order> createOrder(CheckoutIntent intent) async {
    checkouts.add(intent);
    if (onCreate != null) return onCreate!(intent);
    currentOrder = orderFixture(items: intent.items, unit: serverUnitMinor);
    return currentOrder;
  }

  @override
  Future<Order> order(String reference) async {
    orderReads.add(reference);
    return onOrder != null ? onOrder!(reference) : currentOrder;
  }

  @override
  Future<Payment> cash(
    String reference, {
    required String key,
    required int tenderMinor,
  }) async {
    cashRequests.add((reference: reference, key: key, tender: tenderMinor));
    if (onCash != null) return onCash!(reference, key, tenderMinor);
    final payment = paymentFixture(
      amount: currentOrder.totalMinor,
      tender: tenderMinor,
    );
    final intentItems = currentOrder.items
        .map(
          (item) =>
              CheckoutItem(productId: item.productId, quantity: item.quantity),
        )
        .toList();
    currentOrder = orderFixture(
      status: 'paid',
      items: intentItems,
      unit: serverUnitMinor,
      accepted: paymentJson(
        amount: currentOrder.totalMinor,
        tender: tenderMinor,
      ),
    );
    attempts = [payment];
    return payment;
  }

  @override
  Future<Payment> external(String reference, {required String key}) async {
    externalRequests.add((reference: reference, key: key));
    if (onExternal != null) return onExternal!(reference, key);
    throw const CheckoutFailure(CheckoutFailureKind.providerUnavailable);
  }

  @override
  Future<PaymentPage> payments(String reference, {int page = 1}) async {
    paymentReads.add((reference: reference, page: page));
    return onPayments != null
        ? onPayments!(reference, page)
        : PaymentPage(
            items: attempts,
            currentPage: page,
            lastPage: 1,
            total: attempts.length,
          );
  }

  @override
  Future<Payment> reconcile(String reference, int paymentId) async {
    reconciles.add((reference: reference, paymentId: paymentId));
    if (onReconcile != null) return onReconcile!(reference, paymentId);
    return attempts.firstWhere((payment) => payment.id == paymentId);
  }

  @override
  Future<Order> cancel(String reference) async {
    cancellations.add(reference);
    if (onCancel != null) return onCancel!(reference);
    currentOrder = orderFixture(
      status: 'cancelled',
      unit: serverUnitMinor,
      items: currentOrder.items
          .map(
            (item) => CheckoutItem(
              productId: item.productId,
              quantity: item.quantity,
            ),
          )
          .toList(),
    );
    return currentOrder;
  }
}
