import 'package:coffee_management_mobile/features/pos/data/checkout_dto.dart';
import 'package:coffee_management_mobile/features/pos/domain/cart.dart';
import 'package:coffee_management_mobile/features/pos/domain/checkout_intent.dart';
import 'package:coffee_management_mobile/features/pos/domain/exact_money.dart';
import 'package:coffee_management_mobile/features/pos/domain/order.dart';
import 'package:coffee_management_mobile/features/pos/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'checkout_test_support.dart';
import 'pos_test_support.dart';

void main() {
  for (final entry in {
    '0': 0,
    '10': 1000,
    '10.5': 1050,
    '10.50': 1050,
    '0.01': 1,
    '0.10': 10,
    ' 10.50 ': 1050,
    '99999999.99': ExactMoney.maxTender,
  }.entries) {
    test(
      'cash input ${entry.key} converts exactly to ${entry.value} cents',
      () {
        expect(ExactMoney.cashEntry(entry.key), entry.value);
        expect(
          ExactMoney.cashEntry(ExactMoney.entryFor(entry.value)),
          entry.value,
        );
      },
    );
  }
  for (final value in [
    '',
    ' ',
    '-1',
    '+10',
    '.50',
    '10.',
    '10.001',
    '1e2',
    '1,000',
    '\$10.00',
    '01',
    '10.5.0',
    '100000000',
    '100000000.00',
    '１０',
    'NaN',
  ]) {
    test(
      'cash input rejects $value',
      () => expect(() => ExactMoney.cashEntry(value), throwsFormatException),
    );
  }
  test(
    'secure keys are opaque, distinct and comply with the header contract',
    () {
      final keys = {for (var i = 0; i < 40; i++) OperationKey.generate()};
      expect(keys.length, 40);
      for (final key in keys) {
        expect(key.length, 32);
        OperationKey.validate(key);
      }
      for (final value in [
        '',
        'short',
        ' bad-key',
        'key-with-newline\n',
        '!bad-key',
        'a' * 65,
      ]) {
        expect(() => OperationKey.validate(value), throwsArgumentError);
      }
    },
  );
  test(
    'checkout snapshots own exact IDs and quantities without following mutable cart',
    () {
      final cart = Cart()
        ..add(product(id: 2))
        ..add(product())
        ..add(product());
      final intent = CheckoutIntent(
        key: 'synthetic-key',
        items: [
          for (final line in cart.lines)
            CheckoutItem(productId: line.product.id, quantity: line.quantity),
        ],
        previewTotalMinor: cart.totalMinor,
      );
      expect(intent.items.map((item) => item.productId), [1, 2]);
      expect(intent.matchesCart(cart), isTrue);
      cart.increment(1);
      expect(intent.items.first.quantity, 2);
      expect(intent.matchesCart(cart), isFalse);
      expect(() => intent.items.clear(), throwsUnsupportedError);
    },
  );
  test(
    'snapshot rejects invalid quantities, IDs, duplicates and empty intents',
    () {
      expect(
        () => CheckoutItem(productId: 1, quantity: 0),
        throwsArgumentError,
      );
      expect(
        () => CheckoutItem(productId: 1, quantity: 100),
        throwsArgumentError,
      );
      expect(
        () => CheckoutItem(productId: 0, quantity: 1),
        throwsArgumentError,
      );
      expect(
        () => CheckoutIntent(
          key: 'synthetic-key',
          items: [],
          previewTotalMinor: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => CheckoutIntent(
          key: 'synthetic-key',
          items: [
            CheckoutItem(productId: 1, quantity: 1),
            CheckoutItem(productId: 1, quantity: 2),
          ],
          previewTotalMinor: 0,
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'pending and paid order parse persisted snapshots and accepted cash',
    () {
      final pending = CheckoutDto.order(orderJson());
      expect(pending.status, OrderStatus.pendingPayment);
      expect(pending.totalMinor, 325);
      expect(pending.items.single.unitPriceMinor, 325);
      final paid = CheckoutDto.order(orderJson(status: 'paid'));
      expect(paid.acceptedPayment!.changeMinor, 675);
      expect(paid.paidAt, DateTime.utc(2026, 10, 7, 1));
    },
  );
  for (final status in [
    'initiated',
    'pending',
    'confirmed',
    'failed',
    'expired',
    'uncertain',
  ]) {
    test('strict external status $status and nullable display fields', () {
      final payment = CheckoutDto.payment(
        paymentJson(method: 'external', status: status),
      );
      expect(payment.status.name, status);
      expect(payment.tenderMinor, isNull);
      expect(payment.changeMinor, isNull);
      expect(payment.qrPayload, isNull);
    });
  }
  for (final fields in <String, Map<String, Object?>>{
    'unknown method': {'method': 'bank'},
    'unknown status': {'status': 'completed'},
    'wrong currency': {'currency': 'KHR'},
    'numeric cents': {'expected_amount_minor': 325},
    'leading zero': {'expected_amount_minor': '0325'},
    'newline cents': {'expected_amount_minor': '325\n'},
    'too-large tender': {'tender_minor': '10000000000'},
    'negative change': {'change_minor': '-1'},
    'wrong change': {'change_minor': '674'},
    'invalid identity': {'id': '1'},
    'invalid flag': {'reconciliation_required': 1},
    'invalid ISO date': {'verified_at': '2026-02-30T00:00:00Z'},
    'cash missing tender': {'tender_minor': null},
    'cash provider': {'provider': 'synthetic'},
    'terminal display payload': {'qr_payload': 'SYNTHETIC-QR'},
  }.entries) {
    test('payment rejects ${fields.key}', () {
      expect(
        () => CheckoutDto.payment({...paymentJson(), ...fields.value}),
        throwsFormatException,
      );
    });
  }
  for (final fields in <String, Map<String, Object?>>{
    'unknown order state': {'status': 'completed'},
    'wrong currency': {'currency': 'KHR'},
    'numeric total': {'total_minor': 325},
    'leading zero': {'subtotal_minor': '0325'},
    'wrong total': {'total_minor': '326'},
    'invented tax': {'tax_minor': '1'},
    'missing line items': {'items': []},
    'invalid reference': {'public_reference': '1'},
    'newline reference': {'public_reference': '$orderReference\n'},
    'invalid creator': {
      'creator': {'id': 0, 'name': 'Staff'},
    },
    'normalised invalid calendar': {'created_at': '2026-02-30T01:00:00Z'},
    'date-only timestamp': {'created_at': '2026-10-07'},
    'timezone-less timestamp': {'created_at': '2026-10-07T00:00:00'},
  }.entries) {
    test(
      'order rejects ${fields.key}',
      () => expect(
        () => CheckoutDto.order({...orderJson(), ...fields.value}),
        throwsFormatException,
      ),
    );
  }
  test(
    'paid requires accepted confirmed payment, exact matching amount and paid timestamp',
    () {
      for (final field in ['accepted_payment', 'paid_at']) {
        expect(
          () => CheckoutDto.order(orderJson(status: 'paid')..remove(field)),
          throwsFormatException,
        );
      }
      expect(
        () => CheckoutDto.order(
          orderJson(status: 'paid', accepted: paymentJson(amount: 324)),
        ),
        throwsFormatException,
      );
      expect(
        () => CheckoutDto.order({
          ...orderJson(),
          'accepted_payment': paymentJson(),
        }),
        throwsFormatException,
      );
      final review = CheckoutDto.order(
        orderJson(status: 'paid', accepted: paymentJson(review: true)),
      );
      expect(review.acceptedPayment!.reconciliationRequired, isTrue);
    },
  );
  test(
    'line money and duplicate identity must agree with immutable order facts',
    () {
      expect(
        () => CheckoutDto.item({...orderItemJson(), 'quantity': 2}),
        throwsFormatException,
      );
      expect(
        () => CheckoutDto.item({...orderItemJson(), 'quantity': '1'}),
        throwsFormatException,
      );
      expect(
        () => CheckoutDto.order({
          ...orderJson(),
          'items': [orderItemJson(), orderItemJson(line: 2)],
          'subtotal_minor': '650',
          'total_minor': '650',
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'display expiry hides cached payload without declaring payment terminal',
    () {
      final payment = paymentFixture(
        method: 'external',
        status: 'pending',
        payload: 'SYNTHETIC-QR',
        expires: '2026-10-07T01:01:00Z',
      );
      expect(
        payment.displayPayload(DateTime.utc(2026, 10, 7, 1)),
        'SYNTHETIC-QR',
      );
      expect(payment.displayPayload(DateTime.utc(2026, 10, 7, 1, 1)), isNull);
      expect(payment.status, PaymentStatus.pending);
    },
  );
  test('additive optional fields do not break strict required fields', () {
    expect(
      CheckoutDto.order({
        ...orderJson(),
        'future_optional': 'value',
      }).totalMinor,
      325,
    );
    expect(
      CheckoutDto.payment({...paymentJson(), 'future_optional': true}).status,
      PaymentStatus.confirmed,
    );
    expect(
      () => CheckoutDto.payment(paymentJson()..remove('qr_payload')),
      throwsFormatException,
    );
  });
}
