import 'package:flutter/material.dart';

import '../../../shared/navigation/app_destinations.dart';
import '../../../shared/theme/app_breakpoints.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/cafe_theme_extension.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../preview/presentation/design_system_preview_page.dart';
import '../../pos/presentation/pos_controller.dart';
import '../../pos/presentation/pos_page.dart';
import 'destination_pages.dart';

/// Primary production authenticated application shell for the Premium Café OS.
///
/// Implements adaptive responsive layouts:
/// - Compact (<600dp): Bottom NavigationBar with prominent POS action and "More" overflow.
/// - Medium / Expanded (≥600dp): Persistent left sidebar / NavigationRail with brand header,
///   staff profile, permission-gated destinations, theme toggle, and sign-out action.
class AdaptiveAppShell extends StatefulWidget {
  const AdaptiveAppShell({
    super.key,
    required this.authController,
    required this.posController,
    this.onToggleTheme,
    this.currentThemeMode = ThemeMode.light,
    this.initialPath,
  });

  final AuthController authController;
  final PosController? posController;
  final VoidCallback? onToggleTheme;
  final ThemeMode currentThemeMode;
  final String? initialPath;

  @override
  State<AdaptiveAppShell> createState() => _AdaptiveAppShellState();
}

class _AdaptiveAppShellState extends State<AdaptiveAppShell> {
  late String _currentPath;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? _defaultPathForUser();
  }

  /// Selects the initial destination based on user role and permissions.
  /// Cashier lands directly on `/pos`; Managers and Admins land on `/dashboard`.
  String _defaultPathForUser() {
    final state = widget.authController.state;
    if (state is Authenticated) {
      if (state.user.role.isCashier) {
        return '/pos';
      }
      return '/dashboard';
    }
    return '/pos';
  }

  AuthUser? get _currentUser {
    final state = widget.authController.state;
    if (state is Authenticated) {
      return state.user;
    }
    return null;
  }

  bool _hasPermission(String permission) {
    return _currentUser?.hasPermission(permission) ?? false;
  }

  void _navigateTo(String path) {
    if (_currentPath != path) {
      setState(() {
        _currentPath = path;
      });
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await widget.authController.logout();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    }
  }

  void _openDesignSystemPreview(BuildContext context) {
    final theme = Theme.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DesignSystemPreviewPage(
          themeMode: theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isCompact = AppBreakpoints.isCompact(context);

    if (isCompact) {
      return _buildCompactShell(context, user);
    } else {
      return _buildExpandedShell(context, user);
    }
  }

  // =========================================================================
  // Compact (Mobile < 600dp) Layout
  // =========================================================================
  Widget _buildCompactShell(BuildContext context, AuthUser user) {
    final theme = Theme.of(context);

    final compactItems = filterDestinations(
      compactDestinations,
      user.hasPermission,
    );

    // Compute active index for bottom navigation bar
    var selectedIndex = compactItems.indexWhere((d) => d.path == _currentPath);
    if (selectedIndex < 0) {
      // If current path is an overflow item (e.g. /products, /reports, /staff, /settings),
      // mark "More" (last item) as selected.
      selectedIndex = compactItems.indexWhere((d) => d.path == '/more');
      if (selectedIndex < 0) selectedIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffee Management System'),
        actions: [
          StatusBadge(
            label: user.role.label.toUpperCase(),
            variant: user.role.isAdmin
                ? StatusBadgeVariant.warning
                : StatusBadgeVariant.success,
            isPill: true,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: _buildCurrentPage(context, user),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          final destination = compactItems[index];
          _navigateTo(destination.path);
        },
        destinations: compactItems.map((destination) {
          final isPos = destination.path == '/pos';
          final isSelected =
              compactItems[selectedIndex].path == destination.path;

          if (isPos) {
            // Emphasized POS destination in bottom bar
            return NavigationDestination(
              icon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                  borderRadius: AppRadius.radiusPill,
                ),
                child: Icon(
                  destination.icon,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onPrimaryContainer,
                  size: 22.0,
                ),
              ),
              selectedIcon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: AppRadius.radiusPill,
                ),
                child: Icon(
                  destination.selectedIcon,
                  color: theme.colorScheme.onPrimary,
                  size: 22.0,
                ),
              ),
              label: destination.label,
              tooltip: 'Point of Sale',
            );
          }

          return NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
            tooltip: destination.label,
          );
        }).toList(),
      ),
    );
  }

  // =========================================================================
  // Expanded (Tablet & Desktop ≥ 600dp) Layout
  // =========================================================================
  Widget _buildExpandedShell(BuildContext context, AuthUser user) {
    final theme = Theme.of(context);
    final cafeExt = CafeThemeExtension.of(context);

    final allowedDestinations = filterDestinations(
      expandedDestinations,
      user.hasPermission,
    );

    return Scaffold(
      body: Row(
        children: [
          // --- Persistent Side Navigation Sidebar ---
          Material(
            color: theme.colorScheme.surface,
            child: Container(
              width: 280.0,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1.0,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Brand Header ---
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: AppRadius.radiusMd,
                            ),
                            child: Icon(
                              Icons.coffee_rounded,
                              color: theme.colorScheme.onPrimary,
                              size: 24,
                            ),
                          ),
                          AppSpacing.gapHorizontalMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Coffee Management System',
                                  style: AppTypography.label.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'ប្រព័ន្ធគ្រប់គ្រងហាងកាហ្វេ',
                                  style: AppTypography.small.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- User Profile Card ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: cafeExt.borderSubtle.withValues(alpha: 0.5),
                          borderRadius: AppRadius.radiusMd,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: AppTypography.label.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            AppSpacing.gapHorizontalSm,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    user.name,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    user.email,
                                    style: AppTypography.small.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: StatusBadge(
                                      label: user.role.label.toUpperCase(),
                                      variant: user.role.isAdmin
                                          ? StatusBadgeVariant.warning
                                          : StatusBadgeVariant.success,
                                      isPill: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    AppSpacing.gapVerticalSm,
                    const Divider(height: 1),
                    AppSpacing.gapVerticalSm,

                    // --- Navigation List ---
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        children: allowedDestinations.map((destination) {
                          final isSelected = _currentPath == destination.path;
                          final isPos = destination.path == '/pos';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Material(
                              color: isSelected
                                  ? (isPos
                                        ? cafeExt.accentCaramel.withValues(
                                            alpha: 0.2,
                                          )
                                        : theme.colorScheme.primaryContainer)
                                  : Colors.transparent,
                              borderRadius: AppRadius.radiusMd,
                              child: InkWell(
                                borderRadius: AppRadius.radiusMd,
                                onTap: () => _navigateTo(destination.path),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: AppSpacing.minTouchTarget,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? destination.selectedIcon
                                            : destination.icon,
                                        color: isSelected
                                            ? (isPos
                                                  ? cafeExt.accentCaramel
                                                  : theme.colorScheme.primary)
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        size: 22,
                                      ),
                                      AppSpacing.gapHorizontalMd,
                                      Expanded(
                                        child: Text(
                                          destination.label,
                                          style: AppTypography.body.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? theme.colorScheme.onSurface
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      if (isPos)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6.0,
                                            vertical: 2.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius: AppRadius.radiusPill,
                                          ),
                                          child: Text(
                                            'MAIN',
                                            style: AppTypography.small.copyWith(
                                              color:
                                                  theme.colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9.0,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const Divider(height: 1),

                    // --- Bottom Controls ---
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        children: [
                          // Design System Preview
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.palette_outlined,
                              size: 20,
                            ),
                            title: const Text('Design System'),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusMd,
                            ),
                            onTap: () => _openDesignSystemPreview(context),
                          ),

                          // Theme Toggle
                          if (widget.onToggleTheme != null)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                widget.currentThemeMode == ThemeMode.dark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                size: 20,
                              ),
                              title: Text(
                                widget.currentThemeMode == ThemeMode.dark
                                    ? 'Light Mode'
                                    : 'Dark Mode',
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.radiusMd,
                              ),
                              onTap: widget.onToggleTheme,
                            ),

                          // Sign Out Action
                          ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.logout_rounded,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            title: Text(
                              'Sign Out',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusMd,
                            ),
                            onTap: () => _handleLogout(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Main Content Area ---
          Expanded(child: _buildCurrentPage(context, user)),
        ],
      ),
    );
  }

  // =========================================================================
  // Destination Page Resolution
  // =========================================================================
  Widget _buildCurrentPage(BuildContext context, AuthUser user) {
    switch (_currentPath) {
      case '/dashboard':
        return const DashboardPlaceholderPage();
      case '/pos':
        if (!user.hasPermission('process-pos') ||
            widget.posController == null) {
          return const PlaceholderDestinationPage(
            title: 'POS access denied',
            icon: Icons.lock_outline,
            subtitle: 'Contact your manager for access.',
          );
        }
        return PosPage(controller: widget.posController!);
      case '/orders':
        return const OrdersPlaceholderPage();
      case '/products':
        return const ProductsPlaceholderPage();
      case '/inventory':
      case '/stock':
        return const InventoryPlaceholderPage();
      case '/reports':
        return const ReportsPlaceholderPage();
      case '/staff':
        return const StaffPlaceholderPage();
      case '/settings':
        return const SettingsPlaceholderPage();
      case '/more':
        return MorePage(
          userName: user.name,
          userRole: user.role.label,
          onLogout: () => _handleLogout(context),
          onNavigate: (path) => _navigateTo(path),
          availableDestinations: buildMoreMenuItems(
            hasPermission: _hasPermission,
          ),
        );
      case '/home':
      default:
        // For compact layout default, or unrecognized routes
        return const HomePlaceholderPage();
    }
  }
}
