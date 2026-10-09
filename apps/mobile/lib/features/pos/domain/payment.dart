enum PaymentMethod { cash, external }

enum PaymentStatus { initiated, pending, confirmed, failed, expired, uncertain }

class Payment {
  const Payment({
    required this.id,
    required this.method,
    required this.status,
    required this.expectedAmountMinor,
    required this.reconciliationRequired,
    this.tenderMinor,
    this.changeMinor,
    this.provider,
    this.expiresAt,
    this.verifiedAt,
    this.createdAt,
    this.qrPayload,
  });
  final int id;
  final PaymentMethod method;
  final PaymentStatus status;
  final int expectedAmountMinor;
  final int? tenderMinor;
  final int? changeMinor;
  final String? provider;
  final bool reconciliationRequired;
  final DateTime? expiresAt;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final String? qrPayload;
  String get currency => 'USD';

  bool get blocksSettlement =>
      reconciliationRequired ||
      status == PaymentStatus.initiated ||
      status == PaymentStatus.pending ||
      status == PaymentStatus.uncertain ||
      status == PaymentStatus.confirmed;

  String? displayPayload(DateTime now) =>
      status == PaymentStatus.pending &&
          (expiresAt == null || now.isBefore(expiresAt!))
      ? qrPayload
      : null;
}

class PaymentPage {
  PaymentPage({
    required List<Payment> items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  }) : items = List.unmodifiable(items);
  final List<Payment> items;
  final int currentPage;
  final int lastPage;
  final int total;
  bool get hasMore => currentPage < lastPage && currentPage < 10000;
}
