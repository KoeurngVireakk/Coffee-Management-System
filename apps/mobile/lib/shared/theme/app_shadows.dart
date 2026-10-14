import 'package:flutter/widgets.dart';

/// Semantic elevation and shadow tokens for the Premium Café OS design system.
///
/// Uses subtle warm ambient tints instead of harsh black drop shadows to evoke
/// artisanal depth and physical paper/card presence.
abstract final class AppShadows {
  /// Subtle resting card shadow for light theme.
  static const List<BoxShadow> cardRestingLight = [
    BoxShadow(color: Color(0x0A3A2618), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Subtle resting card shadow for dark theme.
  static const List<BoxShadow> cardRestingDark = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Elevated card shadow for interactive/hover/focus states.
  static const List<BoxShadow> cardElevatedLight = [
    BoxShadow(color: Color(0x143A2618), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Elevated card shadow for dark theme.
  static const List<BoxShadow> cardElevatedDark = [
    BoxShadow(color: Color(0x3D000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Floating sheet / bottom modal shadow.
  static const List<BoxShadow> sheetLight = [
    BoxShadow(color: Color(0x193A2618), blurRadius: 24, offset: Offset(0, -4)),
  ];

  /// Floating sheet / bottom modal shadow for dark theme.
  static const List<BoxShadow> sheetDark = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, -4)),
  ];
}
