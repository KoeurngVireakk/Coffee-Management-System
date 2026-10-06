/// Navigation destination definitions for the Premium Café OS adaptive shell.
///
/// Destinations are permission-gated: only destinations whose [requiredPermission]
/// is satisfied by the authenticated user's server-granted permissions are
/// displayed. Backend authorization remains authoritative regardless of UI hiding.
library;

import 'package:flutter/material.dart';

/// A navigation destination in the adaptive app shell.
///
/// Each destination maps to a top-level route and declares the permission
/// required to make it visible. The [permission] field references the
/// server-granted permission string from the authenticated session.
/// A null permission means the destination is always visible to any
/// authenticated user.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
    this.permission,
  });

  /// Human-readable destination label displayed in navigation.
  final String label;

  /// Icon displayed in the unselected state.
  final IconData icon;

  /// Icon displayed in the selected/active state.
  final IconData selectedIcon;

  /// Route path for GoRouter navigation.
  final String path;

  /// Server-granted permission required for this destination to be visible.
  /// Null means always visible to authenticated users.
  final String? permission;
}

/// All available navigation destinations for compact (mobile) layout.
///
/// POS is the cashier's primary workflow and receives visual emphasis.
const List<AppDestination> compactDestinations = [
  AppDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    path: '/home',
  ),
  AppDestination(
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    path: '/orders',
    permission: 'view-own-orders',
  ),
  AppDestination(
    label: 'POS',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    path: '/pos',
    permission: 'process-pos',
  ),
  AppDestination(
    label: 'Stock',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    path: '/stock',
    permission: 'view-inventory',
  ),
  AppDestination(
    label: 'More',
    icon: Icons.more_horiz_rounded,
    selectedIcon: Icons.more_horiz_rounded,
    path: '/more',
  ),
];

/// All available navigation destinations for expanded (tablet/desktop) layout.
///
/// Provides the full feature set with explicit entries for management screens.
const List<AppDestination> expandedDestinations = [
  AppDestination(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    path: '/dashboard',
  ),
  AppDestination(
    label: 'POS',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    path: '/pos',
    permission: 'process-pos',
  ),
  AppDestination(
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    path: '/orders',
    permission: 'view-own-orders',
  ),
  AppDestination(
    label: 'Products',
    icon: Icons.coffee_outlined,
    selectedIcon: Icons.coffee_rounded,
    path: '/products',
    permission: 'view-catalog',
  ),
  AppDestination(
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    path: '/inventory',
    permission: 'view-inventory',
  ),
  AppDestination(
    label: 'Reports',
    icon: Icons.analytics_outlined,
    selectedIcon: Icons.analytics_rounded,
    path: '/reports',
    permission: 'view-reports',
  ),
  AppDestination(
    label: 'Staff',
    icon: Icons.people_outlined,
    selectedIcon: Icons.people_rounded,
    path: '/staff',
    permission: 'manage-staff',
  ),
  AppDestination(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    path: '/settings',
    permission: 'manage-settings',
  ),
];

/// Filters destinations to only those the user has permission to see.
///
/// Destinations with null permission are always included.
/// The [hasPermission] callback references the authenticated user's
/// server-granted permissions list.
List<AppDestination> filterDestinations(
  List<AppDestination> destinations,
  bool Function(String permission) hasPermission,
) {
  return destinations
      .where((d) => d.permission == null || hasPermission(d.permission!))
      .toList(growable: false);
}
