import 'package:flutter/material.dart';

import '../../../shared/theme/app_breakpoints.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/cafe_theme_extension.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../preview/presentation/design_system_preview_page.dart';
import '../domain/auth_session.dart';
import 'auth_controller.dart';

/// Temporary authenticated landing view proving live session state and role verification.
///
/// Phase 3 will replace this placeholder with the adaptive App Shell and role navigation.
class AuthenticatedPlaceholderPage extends StatelessWidget {
  const AuthenticatedPlaceholderPage({
    super.key,
    required this.session,
    required this.authController,
  });

  final AuthSession session;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cafeExt = CafeThemeExtension.of(context);
    final user = session.user;
    final horizontalPadding = AppBreakpoints.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffee Management System'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _handleLogout(context),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: AppSpacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Active Session Card ---
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: cafeExt.positiveSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: cafeExt.positiveOnSurface,
                                size: 28,
                              ),
                            ),
                            AppSpacing.gapHorizontalMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: AppTypography.title.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  AppSpacing.gapVerticalXs,
                                  Text(
                                    user.email,
                                    style: AppTypography.body.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: user.role.label.toUpperCase(),
                              variant: StatusBadgeVariant.success,
                              isPill: true,
                            ),
                          ],
                        ),
                        AppSpacing.gapVerticalLg,
                        const Divider(),
                        AppSpacing.gapVerticalMd,

                        // Session Metadata
                        _buildMetaRow('Staff ID', '#${user.id}', theme),
                        AppSpacing.gapVerticalSm,
                        _buildMetaRow('Assigned Role', user.role.label, theme),
                        AppSpacing.gapVerticalSm,
                        _buildMetaRow(
                          'Session Status',
                          session.isExpired ? 'Expired' : 'Active & Verified',
                          theme,
                          color: session.isExpired
                              ? cafeExt.errorOnSurface
                              : cafeExt.positiveOnSurface,
                        ),
                        AppSpacing.gapVerticalSm,
                        _buildMetaRow(
                          'Expires At (UTC)',
                          session.expiresAt.toIso8601String(),
                          theme,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVerticalLg,

                  // --- Authoritative Permissions Card ---
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server-Granted Permissions (${user.permissions.length})',
                          style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        AppSpacing.gapVerticalSm,
                        if (user.permissions.isEmpty)
                          Text(
                            'No explicit permissions assigned.',
                            style: AppTypography.body.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: user.permissions.map((p) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm + 2,
                                  vertical: AppSpacing.xs + 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: AppRadius.radiusSm,
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  p,
                                  style: AppTypography.small.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVerticalXl,

                  // --- Actions ---
                  AppButton(
                    label: 'Sign Out',
                    variant: AppButtonVariant.destructive,
                    leadingIcon: Icons.logout_rounded,
                    isFullWidth: true,
                    onPressed: () => _handleLogout(context),
                  ),
                  AppSpacing.gapVerticalMd,

                  // Developer Link to Design System Preview
                  AppButton(
                    label: 'View Design System Preview',
                    variant: AppButtonVariant.outline,
                    leadingIcon: Icons.palette_outlined,
                    isFullWidth: true,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DesignSystemPreviewPage(
                            themeMode: theme.brightness == Brightness.dark
                                ? ThemeMode.dark
                                : ThemeMode.light,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(
    String label,
    String value,
    ThemeData theme, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.small.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTypography.label.copyWith(
            fontWeight: FontWeight.w600,
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _handleLogout(BuildContext context) async {
    try {
      await authController.logout();
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
}
