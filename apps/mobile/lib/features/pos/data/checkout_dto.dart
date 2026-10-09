import 'dart:convert';
import '../domain/exact_money.dart';
import '../domain/order.dart';
import '../domain/payment.dart';
import 'catalog_dto.dart';

abstract final class CheckoutDto {
  static int money(Object? value, {int max = ExactMoney.maxOrder}) {
    if (value is! String ||
        RegExp(r'^(0|[1-9][0-9]{0,9})$').stringMatch(value) != value) {
      throw const FormatException('Invalid money.');
    }
    final cents = int.parse(value);
    if (cents > max) throw const FormatException('Money out of bounds.');
    return cents;
  }

  static String reference(Object? value) {
    if (value is! String ||
        RegExp(r'^ORD-[0-9A-HJKMNP-TV-Z]{26}$').stringMatch(value) != value) {
      throw const FormatException('Invalid order reference.');
    }
    return value;
  }

  static DateTime? timestamp(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Invalid timestamp.');
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-](\d{2}):(\d{2}))$',
    ).firstMatch(value);
    if (match == null || match.group(0) != value) {
      throw const FormatException('Invalid timestamp.');
    }
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    final calendar = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    final checked = [
      calendar.year,
      calendar.month,
      calendar.day,
      calendar.hour,
      calendar.minute,
      calendar.second,
    ];
    if (parts[0] < 1 ||
        List.generate(6, (i) => parts[i] == checked[i]).contains(false) ||
        (match.group(8) != null &&
            (int.parse(match.group(8)!) > 14 ||
                int.parse(match.group(9)!) > 59 ||
                (int.parse(match.group(8)!) == 14 &&
                    int.parse(match.group(9)!) != 0)))) {
      throw const FormatException('Invalid calendar timestamp.');
    }
    return DateTime.parse(value).toUtc();
  }

  static void _required(Map<String, dynamic> json, List<String> keys) {
    if (keys.any((key) => !json.containsKey(key))) {
      throw const FormatException('Missing required fields.');
    }
  }

  static Payment payment(Object? value) {
    final json = CatalogDto.object(value);
    _required(json, [
      'id',
      'method',
      'status',
      'expected_amount_minor',
      'currency',
      'tender_minor',
      'change_minor',
      'provider',
      'reconciliation_required',
      'expires_at',
      'verified_at',
      'created_at',
      'qr_payload',
    ]);
    final method = switch (json['method']) {
      'cash' => PaymentMethod.cash,
      'external' => PaymentMethod.external,
      _ => throw const FormatException('Unknown payment method.'),
    };
    final status = switch (json['status']) {
      'initiated' => PaymentStatus.initiated,
      'pending' => PaymentStatus.pending,
      'confirmed' => PaymentStatus.confirmed,
      'failed' => PaymentStatus.failed,
      'expired' => PaymentStatus.expired,
      'uncertain' => PaymentStatus.uncertain,
      _ => throw const FormatException('Unknown payment status.'),
    };
    if (json['currency'] != 'USD') {
      throw const FormatException('Invalid currency.');
    }
    final expected = money(json['expected_amount_minor']);
    final tender = json['tender_minor'] == null
        ? null
        : money(json['tender_minor'], max: ExactMoney.maxTender);
    final change = json['change_minor'] == null
        ? null
        : money(json['change_minor'], max: ExactMoney.maxTender);
    final provider = json['provider'] == null
        ? null
        : CatalogDto.text(json['provider'], 191);
    final payload = json['qr_payload'];
    if (payload != null &&
        (payload is! String ||
            payload.isEmpty ||
            utf8.encode(payload).length > 8192 ||
            status != PaymentStatus.pending)) {
      throw const FormatException('Invalid display payload.');
    }
    if (method == PaymentMethod.cash &&
            (tender == null ||
                change == null ||
                tender < expected ||
                change != tender - expected ||
                provider != null) ||
        method == PaymentMethod.external &&
            (tender != null || change != null)) {
      throw const FormatException('Inconsistent payment money.');
    }
    return Payment(
      id: CatalogDto.integer(json['id']),
      method: method,
      status: status,
      expectedAmountMinor: expected,
      tenderMinor: tender,
      changeMinor: change,
      provider: provider,
      reconciliationRequired: CatalogDto.flag(json['reconciliation_required']),
      expiresAt: timestamp(json['expires_at']),
      verifiedAt: timestamp(json['verified_at']),
      createdAt: timestamp(json['created_at']),
      qrPayload: payload as String?,
    );
  }

  static OrderItem item(Object? value) {
    final json = CatalogDto.object(value);
    final unit = money(json['unit_price_minor'], max: 999999);
    final quantity = CatalogDto.integer(json['quantity'], max: 99);
    final subtotal = money(json['subtotal_minor']);
    final discount = money(json['discount_minor']);
    final tax = money(json['tax_minor']);
    final total = money(json['line_total_minor']);
    if (subtotal != unit * quantity ||
        discount != 0 ||
        tax != 0 ||
        total != subtotal) {
      throw const FormatException('Inconsistent order line.');
    }
    return OrderItem(
      lineNumber: CatalogDto.integer(json['line_number'], max: 50),
      productId: CatalogDto.integer(json['product_id']),
      productName: CatalogDto.text(json['product_name'], 160),
      productSku: CatalogDto.text(json['product_sku'], 64),
      unitPriceMinor: unit,
      quantity: quantity,
      subtotalMinor: subtotal,
      discountMinor: discount,
      taxMinor: tax,
      lineTotalMinor: total,
    );
  }

  static Order order(Object? value) {
    final json = CatalogDto.object(value);
    _required(json, ['created_at', 'items', 'creator', 'inventory_tracked']);
    final status = switch (json['status']) {
      'pending_payment' => OrderStatus.pendingPayment,
      'paid' => OrderStatus.paid,
      'cancelled' => OrderStatus.cancelled,
      'expired' => OrderStatus.expired,
      _ => throw const FormatException('Unknown order status.'),
    };
    if (json['currency'] != 'USD' || json['items'] is! List) {
      throw const FormatException('Invalid order.');
    }
    final items = (json['items'] as List).map(item).toList();
    final ids = <int>{};
    if (items.isEmpty ||
        items.length > 50 ||
        List.generate(
          items.length,
          (i) => items[i].lineNumber == i + 1 && ids.add(items[i].productId),
        ).contains(false)) {
      throw const FormatException('Invalid order lines.');
    }
    final subtotal = money(json['subtotal_minor']);
    final discount = money(json['discount_minor']);
    final tax = money(json['tax_minor']);
    final total = money(json['total_minor']);
    if (discount != 0 ||
        tax != 0 ||
        total != subtotal ||
        items.fold(0, (sum, line) => sum + line.subtotalMinor) != subtotal) {
      throw const FormatException('Inconsistent order total.');
    }
    final accepted = json['accepted_payment'] == null
        ? null
        : payment(json['accepted_payment']);
    final paidAt = timestamp(json['paid_at']);
    if (status == OrderStatus.paid &&
            (accepted == null ||
                accepted.status != PaymentStatus.confirmed ||
                accepted.expectedAmountMinor != total ||
                paidAt == null) ||
        status != OrderStatus.paid && (accepted != null || paidAt != null)) {
      throw const FormatException('Inconsistent persisted settlement.');
    }
    final creator = CatalogDto.object(json['creator']);
    return Order(
      reference: reference(json['public_reference']),
      status: status,
      subtotalMinor: subtotal,
      discountMinor: discount,
      taxMinor: tax,
      totalMinor: total,
      inventoryTracked: CatalogDto.flag(json['inventory_tracked']),
      creatorId: CatalogDto.integer(creator['id']),
      creatorName: CatalogDto.text(creator['name'], 255),
      items: items,
      createdAt: timestamp(json['created_at']),
      acceptedPayment: accepted,
      paidAt: paidAt,
    );
  }
}
