import 'package:flutter/animation.dart';

/// Motion durations and animation curves for fluid, accessible feedback.
abstract final class AppMotion {
  // --- Durations ---
  static const Duration press = Duration(milliseconds: 100);
  static const Duration hoverFocus = Duration(milliseconds: 150);
  static const Duration tabSelection = Duration(milliseconds: 180);
  static const Duration dialogSheet = Duration(milliseconds: 200);
  static const Duration pageTransition = Duration(milliseconds: 240);

  // --- Curves ---
  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
}
