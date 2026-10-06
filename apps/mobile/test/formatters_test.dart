import 'package:coffee_management_mobile/shared/theme/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatters.formatCents', () {
    test('formats zero cents correctly', () {
      expect(Formatters.formatCents(0), equals('\$0.00'));
    });

    test('formats single-digit cents with leading zero', () {
      expect(Formatters.formatCents(5), equals('\$0.05'));
    });

    test('formats standard price in cents', () {
      expect(Formatters.formatCents(325), equals('\$3.25'));
      expect(Formatters.formatCents(1200), equals('\$12.00'));
      expect(Formatters.formatCents(9999), equals('\$99.99'));
    });

    test('formats large numbers without precision loss', () {
      expect(Formatters.formatCents(1000000), equals('\$10000.00'));
      expect(Formatters.formatCents(148525), equals('\$1485.25'));
    });

    test('formats negative cents with leading minus', () {
      expect(Formatters.formatCents(-50), equals('-\$0.50'));
      expect(Formatters.formatCents(-325), equals('-\$3.25'));
      expect(Formatters.formatCents(-5), equals('-\$0.05'));
    });
  });

  group('Formatters.formatExactQuantity', () {
    test('formats whole numbers without fractional part', () {
      expect(Formatters.formatExactQuantity('100.0000', 'g'), equals('100 g'));
      expect(Formatters.formatExactQuantity('15.0000', 'kg'), equals('15 kg'));
      expect(Formatters.formatExactQuantity('0.0000', 'kg'), equals('0 kg'));
    });

    test(
      'formats numbers with significant decimals, trimming trailing zeroes',
      () {
        expect(
          Formatters.formatExactQuantity('0.5000', 'ml'),
          equals('0.5 ml'),
        );
        expect(
          Formatters.formatExactQuantity('2.2500', 'unit'),
          equals('2.25 unit'),
        );
        expect(
          Formatters.formatExactQuantity('1.1250', 'l'),
          equals('1.125 l'),
        );
        expect(
          Formatters.formatExactQuantity('3.1415', 'kg'),
          equals('3.1415 kg'),
        );
      },
    );

    test('handles integers without decimal dot', () {
      expect(Formatters.formatExactQuantity('100', 'g'), equals('100 g'));
      expect(Formatters.formatExactQuantity('0', 'unit'), equals('0 unit'));
    });
  });
}
