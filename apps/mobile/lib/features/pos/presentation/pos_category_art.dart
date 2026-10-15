import 'package:flutter/material.dart';

/// Decorative local Material glyphs, never product photos or catalog metadata.
/// Recognized category labels get a familiar motif; unknown labels stay neutral.
IconData posCategoryIcon(String name) {
  final label = name.toLowerCase();
  if (label.contains('coffee') || label.contains('espresso')) {
    return Icons.coffee_outlined;
  }
  if (label.contains('tea') || label.contains('matcha')) {
    return Icons.emoji_food_beverage_outlined;
  }
  if (label.contains('bakery') ||
      label.contains('pastr') ||
      label.contains('bread')) {
    return Icons.bakery_dining_outlined;
  }
  return Icons.restaurant_menu_outlined;
}
