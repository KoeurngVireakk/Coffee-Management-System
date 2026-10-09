/// Frozen USD bounds. All financial values remain exact integers on web/native.
abstract final class ExactMoney {
  static const maxOrder = 4949995050;
  static const maxTender = 9999999999;

  /// Cash entry accepts surrounding whitespace, integer dollars, or one/two
  /// decimal digits. Signs, grouping, exponents and leading zeros are rejected.
  static int cashEntry(String input) {
    final value = input.trim();
    final match = RegExp(
      r'^(0|[1-9][0-9]{0,7})(?:\.([0-9]{1,2}))?$',
    ).firstMatch(value);
    if (match == null || match.group(0) != value) {
      throw const FormatException(
        'Enter dollars with at most two decimal places.',
      );
    }
    final cents =
        int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '').padRight(2, '0'));
    if (cents > maxTender) {
      throw const FormatException('Cash exceeds the supported amount.');
    }
    return cents;
  }

  static String entryFor(int cents) =>
      '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}
