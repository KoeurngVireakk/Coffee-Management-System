import 'package:coffee_management_mobile/features/orders/domain/order_filter.dart';
import 'package:coffee_management_mobile/features/orders/domain/order_history_repository.dart';
import 'package:coffee_management_mobile/features/pos/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderFilter', () {
    test('default constructor creates empty filter', () {
      final filter = OrderFilter();

      expect(filter.status, isNull);
      expect(filter.createdFrom, isNull);
      expect(filter.createdTo, isNull);
      expect(filter.hasDateFilter, isFalse);
      expect(filter.isActive, isFalse);

      final params = filter.toQueryParameters();
      expect(params['page'], '1');
      expect(params['per_page'], '25');
      expect(params.containsKey('status'), isFalse);
      expect(params.containsKey('created_from'), isFalse);
      expect(params.containsKey('created_to'), isFalse);
    });

    test('toQueryParameters serializes only allowed parameters', () {
      final from = DateTime.utc(2026, 10, 1, 0, 0, 0);
      final to = DateTime.utc(2026, 10, 1, 23, 59, 59);

      final filter = OrderFilter(
        status: OrderStatus.paid,
        createdFrom: from,
        createdTo: to,
      );

      final params = filter.toQueryParameters(page: 2, perPage: 15);

      expect(params['status'], 'paid');
      expect(params['created_from'], from.toIso8601String());
      expect(params['created_to'], to.toIso8601String());
      expect(params['page'], '2');
      expect(params['per_page'], '15');

      // Ensure no unauthorized query parameters can ever exist
      expect(params.containsKey('search'), isFalse);
      expect(params.containsKey('sort'), isFalse);
      expect(params.containsKey('order_by'), isFalse);
      expect(params.containsKey('user_id'), isFalse);
      expect(params.containsKey('created_by'), isFalse);
      expect(params.length, 5);
    });

    test('validates page and per_page bounds', () {
      final filter = OrderFilter();

      expect(
        () => filter.toQueryParameters(page: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => filter.toQueryParameters(page: 10001),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => filter.toQueryParameters(perPage: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => filter.toQueryParameters(perPage: 101),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates date boundaries (createdFrom <= createdTo)', () {
      final earlier = DateTime.utc(2026, 10, 1, 10, 0);
      final later = DateTime.utc(2026, 10, 1, 12, 0);

      expect(
        () => OrderFilter(createdFrom: earlier, createdTo: later),
        returnsNormally,
      );

      expect(
        () => OrderFilter(createdFrom: earlier, createdTo: earlier),
        returnsNormally,
      );

      expect(
        () => OrderFilter(createdFrom: later, createdTo: earlier),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calendarDay sets exact start and end of day', () {
      final day = DateTime(2026, 10, 14, 15, 30);
      final filter = OrderFilter.calendarDay(day);

      expect(filter.hasDateFilter, isTrue);
      expect(filter.createdFrom!.year, 2026);
      expect(filter.createdFrom!.month, 10);
      expect(filter.createdFrom!.day, 14);
      expect(filter.createdFrom!.hour, 0);
      expect(filter.createdFrom!.minute, 0);
      expect(filter.createdFrom!.second, 0);

      expect(filter.createdTo!.year, 2026);
      expect(filter.createdTo!.month, 10);
      expect(filter.createdTo!.day, 14);
      expect(filter.createdTo!.hour, 23);
      expect(filter.createdTo!.minute, 59);
      expect(filter.createdTo!.second, 59);
    });

    test('calendarRange sets start of first day and end of last day', () {
      final start = DateTime(2026, 10, 1, 12, 0);
      final end = DateTime(2026, 10, 7, 8, 30);
      final filter = OrderFilter.calendarRange(start, end);

      expect(filter.createdFrom!.day, 1);
      expect(filter.createdFrom!.hour, 0);
      expect(filter.createdTo!.day, 7);
      expect(filter.createdTo!.hour, 23);
    });

    test('copyWith updates fields and clears dates correctly', () {
      final initial = OrderFilter(
        status: OrderStatus.pendingPayment,
        createdFrom: DateTime.utc(2026, 10, 1),
        createdTo: DateTime.utc(2026, 10, 2),
      );

      final updated = initial.copyWith(status: () => OrderStatus.paid);
      expect(updated.status, OrderStatus.paid);
      expect(updated.createdFrom, initial.createdFrom);
      expect(updated.createdTo, initial.createdTo);

      final cleared = initial.copyWith(
        createdFrom: () => null,
        createdTo: () => null,
      );
      expect(cleared.status, OrderStatus.pendingPayment);
      expect(cleared.createdFrom, isNull);
      expect(cleared.createdTo, isNull);
      expect(cleared.hasDateFilter, isFalse);

      final reset = initial.clear();
      expect(reset.isActive, isFalse);
    });

    test('value equality and hashCode', () {
      final f1 = OrderFilter(status: OrderStatus.paid);
      final f2 = OrderFilter(status: OrderStatus.paid);
      final f3 = OrderFilter(status: OrderStatus.cancelled);

      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
      expect(f1, isNot(equals(f3)));
    });

    test('statusToApi and apiToStatus mapping', () {
      expect(
        OrderFilter.statusToApi(OrderStatus.pendingPayment),
        'pending_payment',
      );
      expect(OrderFilter.statusToApi(OrderStatus.paid), 'paid');
      expect(OrderFilter.statusToApi(OrderStatus.cancelled), 'cancelled');
      expect(OrderFilter.statusToApi(OrderStatus.expired), 'expired');

      expect(
        OrderFilter.apiToStatus('pending_payment'),
        OrderStatus.pendingPayment,
      );
      expect(OrderFilter.apiToStatus('paid'), OrderStatus.paid);
      expect(OrderFilter.apiToStatus('cancelled'), OrderStatus.cancelled);
      expect(OrderFilter.apiToStatus('expired'), OrderStatus.expired);
      expect(OrderFilter.apiToStatus('unknown'), isNull);
    });
  });

  group('OrderPage', () {
    test('calculates hasMore correctly', () {
      final pageWithMore = OrderPage(
        items: [],
        currentPage: 1,
        lastPage: 3,
        perPage: 15,
        total: 45,
      );
      expect(pageWithMore.hasMore, isTrue);

      final lastPage = OrderPage(
        items: [],
        currentPage: 3,
        lastPage: 3,
        perPage: 15,
        total: 45,
      );
      expect(lastPage.hasMore, isFalse);
    });
  });

  group('OrderHistoryFailure', () {
    test('provides human-readable messages by kind', () {
      const unauth = OrderHistoryFailure(
        OrderHistoryFailureKind.sessionExpired,
      );
      expect(unauth.message, contains('session has expired'));

      const forbidden = OrderHistoryFailure(OrderHistoryFailureKind.forbidden);
      expect(forbidden.message, contains('permission'));

      const notFound = OrderHistoryFailure(OrderHistoryFailureKind.notFound);
      expect(notFound.message, contains('unavailable or does not exist'));

      const conflict = OrderHistoryFailure(
        OrderHistoryFailureKind.conflict,
        detail: 'State changed',
      );
      expect(conflict.message, 'State changed');

      const validation = OrderHistoryFailure(
        OrderHistoryFailureKind.validation,
        errors: {
          'status': ['The selected status is invalid.'],
        },
      );
      expect(validation.message, 'The selected status is invalid.');

      const rateLimit = OrderHistoryFailure(
        OrderHistoryFailureKind.rateLimited,
      );
      expect(rateLimit.message, contains('wait'));

      const network = OrderHistoryFailure(OrderHistoryFailureKind.network);
      expect(network.message, contains('network'));

      const server = OrderHistoryFailure(OrderHistoryFailureKind.server);
      expect(server.message, contains('service encountered an error'));

      const invalidResp = OrderHistoryFailure(
        OrderHistoryFailureKind.invalidResponse,
      );
      expect(invalidResp.message, contains('invalid response'));
    });
  });
}
