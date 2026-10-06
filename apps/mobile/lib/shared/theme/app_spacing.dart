import 'package:flutter/widgets.dart';

/// 4px base spacing scale and common layout gap tokens.
abstract final class AppSpacing {
  // --- Scale Tokens (4px base) ---
  static const double xs = 2.0;
  static const double s = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
  static const double giant = 48.0;
  static const double massive = 64.0;

  // --- Common Layout Dimensions ---
  static const double screenPaddingMobile = 16.0;
  static const double screenPaddingTablet = 24.0;
  static const double cardPadding = 16.0;
  static const double fieldSpacing = 16.0;
  static const double sectionSpacing = 24.0;
  static const double minTouchTarget = 48.0;

  // --- Common Insets ---
  static const EdgeInsets edgeInsetsXs = EdgeInsets.all(xs);
  static const EdgeInsets edgeInsetsSm = EdgeInsets.all(sm);
  static const EdgeInsets edgeInsetsMd = EdgeInsets.all(md);
  static const EdgeInsets edgeInsetsLg = EdgeInsets.all(lg);
  static const EdgeInsets edgeInsetsXl = EdgeInsets.all(xl);
  static const EdgeInsets edgeInsetsXxl = EdgeInsets.all(xxl);

  // --- Common Gap Widgets (SizedBox) ---
  static const SizedBox gapHorizontalXs = SizedBox(width: xs);
  static const SizedBox gapHorizontalSm = SizedBox(width: sm);
  static const SizedBox gapHorizontalMd = SizedBox(width: md);
  static const SizedBox gapHorizontalLg = SizedBox(width: lg);
  static const SizedBox gapHorizontalXl = SizedBox(width: xl);
  static const SizedBox gapHorizontalXxl = SizedBox(width: xxl);

  static const SizedBox gapVerticalXs = SizedBox(height: xs);
  static const SizedBox gapVerticalSm = SizedBox(height: sm);
  static const SizedBox gapVerticalMd = SizedBox(height: md);
  static const SizedBox gapVerticalLg = SizedBox(height: lg);
  static const SizedBox gapVerticalXl = SizedBox(height: xl);
  static const SizedBox gapVerticalXxl = SizedBox(height: xxl);
  static const SizedBox gapVerticalXxxl = SizedBox(height: xxxl);
  static const SizedBox gapVerticalHuge = SizedBox(height: huge);
  static const SizedBox gapVerticalMassive = SizedBox(height: massive);
}
