import 'package:flutter/widgets.dart';

import 'app_spacing.dart';

/// Screen size categorization for responsive layouts.
enum AppBreakpoint { compact, medium, expanded }

/// Breakpoint tokens and screen-size helper functions.
abstract final class AppBreakpoints {
  static const double compact = 600.0;
  static const double expanded = 900.0;

  static AppBreakpoint of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compact) {
      return AppBreakpoint.compact;
    } else if (width < expanded) {
      return AppBreakpoint.medium;
    } else {
      return AppBreakpoint.expanded;
    }
  }

  static bool isCompact(BuildContext context) =>
      of(context) == AppBreakpoint.compact;

  static bool isMedium(BuildContext context) =>
      of(context) == AppBreakpoint.medium;

  static bool isExpanded(BuildContext context) =>
      of(context) == AppBreakpoint.expanded;

  static bool isTabletOrLarger(BuildContext context) => !isCompact(context);

  /// Selects a value based on the current screen breakpoint.
  static T responsive<T>(
    BuildContext context, {
    required T compact,
    T? medium,
    T? expanded,
  }) {
    final bp = of(context);
    switch (bp) {
      case AppBreakpoint.compact:
        return compact;
      case AppBreakpoint.medium:
        return medium ?? compact;
      case AppBreakpoint.expanded:
        return expanded ?? medium ?? compact;
    }
  }

  /// Standard horizontal screen padding based on breakpoint.
  static double horizontalPadding(BuildContext context) {
    return responsive<double>(
      context,
      compact: AppSpacing.screenPaddingMobile,
      medium: AppSpacing.screenPaddingTablet,
      expanded: AppSpacing.xxxl,
    );
  }
}
