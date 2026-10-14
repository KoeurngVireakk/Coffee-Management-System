/// Safe presentation-level formatting helpers for monetary cents and exact quantities.
///
/// Ensures financial cents and inventory decimals are never coerced into binary
/// double-precision floating point numbers.
abstract final class Formatters {
  /// Formats an exact integer USD cents value into a dollar-and-cents string.
  ///
  /// Examples:
  /// - `formatCents(0)` -> `"$0.00"`
  /// - `formatCents(325)` -> `"$3.25"`
  /// - `formatCents(1200)` -> `"$12.00"`
  /// - `formatCents(-50)` -> `"-$0.50"`
  static String formatCents(int cents) {
    final isNegative = cents < 0;
    final absCents = cents.abs();
    final dollars = absCents ~/ 100;
    final remainder = (absCents % 100).toString().padLeft(2, '0');
    final formatted = '\$$dollars.$remainder';
    return isNegative ? '-$formatted' : formatted;
  }

  /// Formats an exact `DECIMAL(14,4)` quantity string with its base unit.
  ///
  /// Strips unnecessary trailing zeroes after the decimal point without
  /// floating-point roundoff errors.
  ///
  /// Examples:
  /// - `formatExactQuantity("100.0000", "g")` -> `"100 g"`
  /// - `formatExactQuantity("0.5000", "ml")` -> `"0.5 ml"`
  /// - `formatExactQuantity("2.2500", "unit")` -> `"2.25 unit"`
  static String formatExactQuantity(String decimalString, String unit) {
    final parts = decimalString.split('.');
    if (parts.length == 1) {
      return '${parts[0]} $unit';
    }

    final integerPart = parts[0];
    final fractionalPart = parts[1].replaceFirst(RegExp(r'0+$'), '');

    if (fractionalPart.isEmpty) {
      return '$integerPart $unit';
    }
    return '$integerPart.$fractionalPart $unit';
  }

  /// Formats a [DateTime] for order history display, e.g. "Oct 14, 2026 · 10:35 AM".
  static String formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    final day = local.day;
    final year = local.year;
    final hour12 = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year · $hour12:$minute $period';
  }

  /// Formats a [DateTime] as a date only, e.g. "Oct 14, 2026".
  static String formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    final day = local.day;
    final year = local.year;
    return '$month $day, $year';
  }

  /// Formats a [DateTime] as a time only, e.g. "10:35 AM".
  static String formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour12 = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }
}
