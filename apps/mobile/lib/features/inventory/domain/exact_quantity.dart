import 'package:flutter/foundation.dart';

/// Exact DECIMAL(14,4) representation using checked integer subunits.
///
/// 1 base unit = 10,000 integer subunits.
/// Ensures inventory balances, recipes, and movements avoid double-precision
/// binary floating-point roundoff errors and match backend Quantity semantics.
@immutable
class ExactQuantity implements Comparable<ExactQuantity> {
  const ExactQuantity.fromSubunits(this.subunits)
    : assert(
        subunits >= -maxScaled && subunits <= maxScaled,
        'Subunits exceed DECIMAL(14,4) capacity.',
      );

  /// Scaled integer value (1.0000 = 10000 subunits).
  final int subunits;

  /// Fixed subunit scale (10,000 subunits per unit).
  static const int scale = 10000;

  /// Maximum absolute magnitude supported by MySQL DECIMAL(14,4) (9,999,999,999.9999).
  static const int maxScaled = 99999999999999;

  /// Zero quantity constant.
  static const ExactQuantity zero = ExactQuantity.fromSubunits(0);

  static final RegExp _unsignedPattern = RegExp(
    r'^(0|[1-9][0-9]{0,9})(?:\.([0-9]{1,4}))?$',
  );

  static final RegExp _signedPattern = RegExp(
    r'^(-?)(0|[1-9][0-9]{0,9})(?:\.([0-9]{1,4}))?$',
  );

  /// Parses an exact decimal string to [ExactQuantity].
  ///
  /// Rejects floating point notation, scientific notation, excess decimal places (>4),
  /// invalid leading zeros, embedded whitespace, plus signs, and negative zero.
  factory ExactQuantity.parse(String value, {bool signed = false}) {
    final match = (signed ? _signedPattern : _unsignedPattern).firstMatch(
      value,
    );
    if (match == null) {
      throw FormatException(
        'Quantity must be an exact decimal string with at most four decimal places.',
        value,
      );
    }

    final isNegative = signed && match.group(1) == '-';
    final integerPartStr = signed ? match.group(2)! : match.group(1)!;
    final fractionalPartStr = signed ? match.group(3) : match.group(2);

    final integerPart = int.parse(integerPartStr);
    final fractionalPart = fractionalPartStr != null
        ? int.parse(fractionalPartStr.padRight(4, '0'))
        : 0;

    var scaled = (integerPart * scale) + fractionalPart;

    if (isNegative) {
      if (scaled == 0) {
        throw FormatException(
          'Negative zero is not a canonical quantity.',
          value,
        );
      }
      scaled = -scaled;
    }

    if (scaled < -maxScaled || scaled > maxScaled) {
      throw FormatException('Quantity exceeds DECIMAL(14,4) capacity.', value);
    }

    return ExactQuantity.fromSubunits(scaled);
  }

  /// Parses an exact decimal string or returns null if invalid.
  static ExactQuantity? tryParse(String? value, {bool signed = false}) {
    if (value == null) return null;
    try {
      return ExactQuantity.parse(value, signed: signed);
    } on FormatException {
      return null;
    }
  }

  /// Validates whether a raw user input string represents a valid decimal quantity.
  ///
  /// Useful for live form validation before full parsing.
  static bool isValidInput(String value, {bool signed = false}) {
    return tryParse(value.trim(), signed: signed) != null;
  }

  /// Formats this quantity to canonical 4-decimal wire representation (e.g. "18.0000" or "-250.0000").
  String toCanonicalString() {
    final absSubunits = subunits.abs();
    final integerPart = absSubunits ~/ scale;
    final remainder = (absSubunits % scale).toString().padLeft(4, '0');
    final sign = subunits < 0 ? '-' : '';
    return '$sign$integerPart.$remainder';
  }

  /// Formats with standard comma grouping on the integer part (e.g. "4,750.0000" or "-1,000.0000").
  String toFormattedString({bool includeThousands = true}) {
    final absSubunits = subunits.abs();
    final integerPart = absSubunits ~/ scale;
    final remainder = (absSubunits % scale).toString().padLeft(4, '0');
    final sign = subunits < 0 ? '-' : '';

    String integerStr = integerPart.toString();
    if (includeThousands && integerStr.length > 3) {
      final buffer = StringBuffer();
      final length = integerStr.length;
      for (var i = 0; i < length; i++) {
        if (i > 0 && (length - i) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(integerStr[i]);
      }
      integerStr = buffer.toString();
    }

    return '$sign$integerStr.$remainder';
  }

  /// Readable string representation trimming unnecessary trailing zeroes after the decimal point
  /// (e.g. "100" or "0.5" or "2.2575").
  String toReadableString() {
    final absSubunits = subunits.abs();
    final integerPart = absSubunits ~/ scale;
    final remainder = absSubunits % scale;
    final sign = subunits < 0 ? '-' : '';

    if (remainder == 0) {
      return '$sign$integerPart';
    }

    final fractionalStr = remainder
        .toString()
        .padLeft(4, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '$sign$integerPart.$fractionalStr';
  }

  /// Formats the quantity alongside its base unit (e.g. "4,750.0000 g" or "800.0000 ml").
  String formatWithUnit(String unit, {bool compact = false}) {
    final valueStr = compact ? toReadableString() : toFormattedString();
    return '$valueStr $unit';
  }

  bool get isZero => subunits == 0;
  bool get isPositive => subunits > 0;
  bool get isNegative => subunits < 0;

  ExactQuantity abs() => ExactQuantity.fromSubunits(subunits.abs());

  ExactQuantity operator +(ExactQuantity other) {
    final result = subunits + other.subunits;
    if (result < -maxScaled || result > maxScaled) {
      throw StateError('Quantity overflow during addition.');
    }
    return ExactQuantity.fromSubunits(result);
  }

  ExactQuantity operator -(ExactQuantity other) {
    final result = subunits - other.subunits;
    if (result < -maxScaled || result > maxScaled) {
      throw StateError('Quantity overflow during subtraction.');
    }
    return ExactQuantity.fromSubunits(result);
  }

  ExactQuantity operator -() {
    if (subunits == 0) return zero;
    final result = -subunits;
    if (result < -maxScaled || result > maxScaled) {
      throw StateError('Quantity overflow during negation.');
    }
    return ExactQuantity.fromSubunits(result);
  }

  ExactQuantity multiply(int wholeUnits) {
    if (wholeUnits < 0) {
      throw ArgumentError('Whole units multiplier must be non-negative.');
    }
    if (wholeUnits == 0 || subunits == 0) return zero;
    if (wholeUnits > maxScaled ~/ subunits.abs()) {
      throw StateError(
        'Quantity multiplication exceeds DECIMAL(14,4) capacity.',
      );
    }
    return ExactQuantity.fromSubunits(subunits * wholeUnits);
  }

  @override
  int compareTo(ExactQuantity other) => subunits.compareTo(other.subunits);

  bool operator <(ExactQuantity other) => subunits < other.subunits;
  bool operator <=(ExactQuantity other) => subunits <= other.subunits;
  bool operator >(ExactQuantity other) => subunits > other.subunits;
  bool operator >=(ExactQuantity other) => subunits >= other.subunits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExactQuantity && other.subunits == subunits);

  @override
  int get hashCode => subunits.hashCode;

  @override
  String toString() => toCanonicalString();
}
