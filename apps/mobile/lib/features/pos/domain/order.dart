import 'payment.dart';

enum OrderStatus { pendingPayment, paid, cancelled, expired }

class OrderItem {
  const OrderItem({
    required this.lineNumber,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.unitPriceMinor,
    required this.quantity,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.lineTotalMinor,
  });
  final int lineNumber;
  final int productId;
  final String productName;
  final String productSku;
  final int unitPriceMinor;
  final int quantity;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int lineTotalMinor;
}

class Order {
  Order({
    required this.reference,
    required this.status,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.inventoryTracked,
    required this.creatorId,
    required this.creatorName,
    required List<OrderItem> items,
    this.createdAt,
    this.paidAt,
    this.acceptedPayment,
  }) : items = List.unmodifiable(items);
  final String reference;
  final OrderStatus status;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
  final bool inventoryTracked;
  final int creatorId;
  final String creatorName;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final Payment? acceptedPayment;
  final List<OrderItem> items;
  String get currency => 'USD';
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}
