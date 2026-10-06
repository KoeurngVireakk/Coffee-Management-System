import 'package:flutter/material.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_empty_state.dart';

/// Generic placeholder page for destinations not yet implemented.
///
/// Used during Phase 3 to prove navigation architecture before
/// business data integration in future phases.
class PlaceholderDestinationPage extends StatelessWidget {
  const PlaceholderDestinationPage({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: AppEmptyState(
          icon: icon,
          title: title,
          description:
              subtitle ?? 'This feature will be available in a future update.',
        ),
      ),
    );
  }
}

/// Home placeholder for compact mobile navigation.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDestinationPage(
      title: 'Home',
      icon: Icons.home_rounded,
      subtitle: 'Your café overview will appear here.',
    );
  }
}

/// Dashboard placeholder for expanded navigation.
class DashboardPlaceholderPage extends StatelessWidget {
  const DashboardPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDestinationPage(
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
      subtitle: 'Executive metrics and KPIs will appear here.',
    );
  }
}

/// POS placeholder page.
class PosPlaceholderPage extends StatelessWidget {
  const PosPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDestinationPage(
      title: 'Point of Sale',
      icon: Icons.point_of_sale_rounded,
      subtitle: 'Product catalog and checkout will appear here.',
    );
  }
}

/// Orders placeholder page.
class OrdersPlaceholderPage extends StatelessWidget {
  const OrdersPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDestinationPage(
      title: 'Orders',
      icon: Icons.receipt_long_rounded,
      subtitle: 'Order history and tracking will appear here.',
    );
  }
}

/// Products placeholder page.
class ProductsPlaceholderPage extends StatelessWidget {
  const ProductsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDestinationPage(
      title: 'Products',
      icon: Icons.coffee_rounded,
      subtitle: 'Product catalog management will appear here.',
    );
  }
}

/// Inventory / Stock placeholder page.
class InventoryPlaceholderPage extends StatelessWidget {
  const InventoryPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDestinationPage(
      title: 'Inventory',
      icon: Icons.inventory_2_rounded,
      subtitle: 'Stock levels and movements will appear here.',
    );
  }
}

/// Reports placeholder page.
class ReportsPlaceholderPage extends StatelessWidget {
  const ReportsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDestinationPage(
      title: 'Reports',
      icon: Icons.analytics_rounded,
      subtitle: 'Operational reports and analytics will appear here.',
    );
  }
}

/// Staff management placeholder page.
class StaffPlaceholderPage extends StatelessWidget {
  const StaffPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDestinationPage(
      title: 'Staff',
      icon: Icons.people_rounded,
      subtitle: 'Staff management will appear here.',
    );
  }
}

/// Settings placeholder page.
class SettingsPlaceholderPage extends StatelessWidget {
  const SettingsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDestinationPage(
      title: 'Settings',
      icon: Icons.settings_rounded,
      subtitle: 'Shop settings and configuration will appear here.',
    );
  }
}

/// "More" page for compact navigation overflow destinations.
class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.userName,
    required this.userRole,
    required this.onLogout,
    required this.onNavigate,
    required this.availableDestinations,
  });

  final String userName;
  final String userRole;
  final VoidCallback onLogout;
  final void Function(String path) onNavigate;

  /// Destinations not shown in the bottom NavigationBar that should
  /// appear as list items in the "More" screen.
  final List<MoreMenuItem> availableDestinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              // --- User identity header ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: AppTypography.h3.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    AppSpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: AppTypography.title.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          AppSpacing.gapVerticalXs,
                          Text(
                            userRole,
                            style: AppTypography.label.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // --- Overflow navigation destinations ---
              for (final item in availableDestinations)
                ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  minTileHeight: AppSpacing.minTouchTarget,
                  onTap: () => onNavigate(item.path),
                ),

              if (availableDestinations.isNotEmpty) const Divider(),

              // --- Sign Out ---
              ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                minTileHeight: AppSpacing.minTouchTarget,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data class for items in the More menu overflow list.
class MoreMenuItem {
  const MoreMenuItem({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

/// Builds the list of "More" menu items for destinations visible to
/// the user but not shown in the compact bottom navigation bar.
List<MoreMenuItem> buildMoreMenuItems({
  required bool Function(String permission) hasPermission,
}) {
  final items = <MoreMenuItem>[];

  // Products - available to users with view-catalog
  if (hasPermission('view-catalog')) {
    items.add(
      const MoreMenuItem(
        label: 'Products',
        icon: Icons.coffee_rounded,
        path: '/products',
      ),
    );
  }

  // Reports - available to users with view-reports
  if (hasPermission('view-reports')) {
    items.add(
      const MoreMenuItem(
        label: 'Reports',
        icon: Icons.analytics_rounded,
        path: '/reports',
      ),
    );
  }

  // Staff - available to users with manage-staff
  if (hasPermission('manage-staff')) {
    items.add(
      const MoreMenuItem(
        label: 'Staff',
        icon: Icons.people_rounded,
        path: '/staff',
      ),
    );
  }

  // Settings - available to users with manage-settings
  if (hasPermission('manage-settings')) {
    items.add(
      const MoreMenuItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
        path: '/settings',
      ),
    );
  }

  return items;
}
