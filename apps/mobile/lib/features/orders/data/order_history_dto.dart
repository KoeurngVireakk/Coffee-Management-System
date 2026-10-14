import '../../pos/data/catalog_dto.dart';
import '../../pos/data/checkout_dto.dart';
import '../../pos/domain/payment.dart';
import '../domain/order_history_repository.dart';

/// Data transfer object parsing for order history collection responses.
abstract final class OrderHistoryDto {
  /// Decodes and strictly validates a paginated order collection response.
  static OrderPage orderPage(
    Object? value, {
    required int requestedPage,
    required int requestedPerPage,
  }) {
    final catalogPage = CatalogDto.page(
      value,
      CheckoutDto.order,
      requestedPage: requestedPage,
      requestedPerPage: requestedPerPage,
    );

    // Verify all references in the page are unique
    final references = <String>{};
    for (final order in catalogPage.items) {
      if (!references.add(order.reference)) {
        throw const FormatException('Duplicate order reference in page data.');
      }
    }

    return OrderPage(
      items: catalogPage.items,
      currentPage: catalogPage.currentPage,
      lastPage: catalogPage.lastPage,
      perPage: catalogPage.perPage,
      total: catalogPage.total,
    );
  }

  /// Decodes and strictly validates a paginated payment collection response.
  static PaymentPage paymentPage(
    Object? value, {
    required int requestedPage,
    required int requestedPerPage,
  }) {
    final catalogPage = CatalogDto.page(
      value,
      CheckoutDto.payment,
      requestedPage: requestedPage,
      requestedPerPage: requestedPerPage,
    );

    final paymentIds = <int>{};
    for (final payment in catalogPage.items) {
      if (!paymentIds.add(payment.id)) {
        throw const FormatException('Duplicate payment ID in page data.');
      }
    }

    return PaymentPage(
      items: catalogPage.items,
      currentPage: catalogPage.currentPage,
      lastPage: catalogPage.lastPage,
      total: catalogPage.total,
    );
  }
}
