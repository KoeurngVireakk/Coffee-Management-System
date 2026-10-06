import 'package:flutter/widgets.dart';

/// Border radius tokens for component consistency.
abstract final class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0; // chips
  static const double md = 10.0; // inputs
  static const double lg = 12.0; // buttons
  static const double xl = 16.0; // cards
  static const double xxl = 20.0; // dialogs / sheets
  static const double pill = 999.0; // pill badges

  // --- BorderRadius objects ---
  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius radiusPill = BorderRadius.all(
    Radius.circular(pill),
  );
}
