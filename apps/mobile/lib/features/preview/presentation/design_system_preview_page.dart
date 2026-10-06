import 'package:flutter/material.dart';

import '../../../shared/theme/app_breakpoints.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/cafe_theme_extension.dart';
import '../../../shared/theme/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_badge.dart';

/// Interactive showcase demonstrating the Premium Café OS design tokens,
/// responsive layouts, Khmer typography, and accessible component library.
class DesignSystemPreviewPage extends StatefulWidget {
  const DesignSystemPreviewPage({
    super.key,
    required this.themeMode,
    this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final VoidCallback? onToggleTheme;

  @override
  State<DesignSystemPreviewPage> createState() =>
      _DesignSystemPreviewPageState();
}

class _DesignSystemPreviewPageState extends State<DesignSystemPreviewPage> {
  final TextEditingController _textController = TextEditingController(
    text: 'Barista Sothea',
  );
  int _counter = 0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cafeExt = CafeThemeExtension.of(context);
    final isDark =
        widget.themeMode == ThemeMode.dark ||
        theme.brightness == Brightness.dark;
    final horizontalPadding = AppBreakpoints.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Coffee Management System'),
            Text(
              'Premium Café OS • Design System',
              style: AppTypography.small.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: widget.onToggleTheme,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Intro Banner ---
              _buildIntroBanner(context, isDark),
              AppSpacing.gapVerticalXl,

              // --- 2. Color Palette ---
              const AppSectionHeader(
                title: 'Color Palette (60-25-10-5 Rule)',
                subtitle:
                    'Warm cream background, deep espresso structure, forest green accents, caramel highlights.',
              ),
              _buildColorPalette(context, cafeExt),
              AppSpacing.gapVerticalXl,

              // --- 3. Typography Scale & Khmer Showcase ---
              const AppSectionHeader(
                title: 'Typography & Khmer Support',
                subtitle:
                    'Inter for English and Noto Sans Khmer with safe line-heights (1.35-1.45) for subscripts.',
              ),
              _buildTypographySection(context),
              AppSpacing.gapVerticalXl,

              // --- 4. Scannable Numeric & Financial Figures ---
              const AppSectionHeader(
                title: 'Financial Figures & Numeric Data',
                subtitle:
                    'Integer cents and exact decimal quantities without floating-point distortion.',
              ),
              _buildFinancialSection(context, cafeExt),
              AppSpacing.gapVerticalXl,

              // --- 5. Button Matrix ---
              const AppSectionHeader(
                title: 'Buttons & Touch Targets',
                subtitle:
                    'Accessible 48x48 min touch targets across all semantic states.',
              ),
              _buildButtonsSection(context),
              AppSpacing.gapVerticalXl,

              // --- 6. Form Inputs ---
              const AppSectionHeader(
                title: 'Form Inputs',
                subtitle:
                    'Accessible text fields with hint, helper, error, and disabled states.',
              ),
              _buildInputsSection(context),
              AppSpacing.gapVerticalXl,

              // --- 7. Status Badges ---
              const AppSectionHeader(
                title: 'Status Badges',
                subtitle:
                    'Multi-attribute indicators combining color, text, and icons.',
              ),
              _buildBadgesSection(context),
              AppSpacing.gapVerticalXl,

              // --- 8. Cards & Empty State ---
              const AppSectionHeader(
                title: 'Surfaces & Cards',
                subtitle:
                    'Rounded borders with subtle lines and generous whitespace.',
              ),
              _buildSurfacesSection(context, cafeExt),
              AppSpacing.gapVerticalHuge,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroBanner(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final cafeExt = CafeThemeExtension.of(context);

    return AppCard(
      backgroundColor: isDark
          ? theme.colorScheme.surface
          : AppColors.latte.withValues(alpha: 0.6),
      borderColor: theme.colorScheme.outlineVariant,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cafeExt.accentCaramel.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_cafe_rounded,
              color: cafeExt.accentCaramel,
              size: 28,
            ),
          ),
          AppSpacing.gapHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Cambodian Café OS Foundation',
                  style: AppTypography.title.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                AppSpacing.gapVerticalXs,
                Text(
                  'Active Mode: ${isDark ? "Dark Theme" : "Light Theme"} • Breakpoint: ${AppBreakpoints.of(context).name.toUpperCase()}',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.gapVerticalSm,
                Text(
                  'Designed for fast cashier throughput, bilingual English & Khmer operation, high visual polish, and zero floating-point financial ambiguity.',
                  style: AppTypography.body.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPalette(BuildContext context, CafeThemeExtension cafeExt) {
    final colors = <(String, Color, String)>[
      ('Espresso', AppColors.espresso, 'Primary brand structure'),
      ('Forest Green', AppColors.forestGreen, 'Action & Confirmation'),
      ('Caramel', AppColors.caramel, 'Accent & Highlighting'),
      ('Warm Cream', AppColors.warmCream, 'Light background (60%)'),
      ('Latte', AppColors.latte, 'Secondary card fill'),
      ('Success', cafeExt.positiveOnSurface, 'Completed & active states'),
      ('Warning', cafeExt.warningOnSurface, 'Low stock & alerts'),
      ('Error', cafeExt.errorOnSurface, 'Failures & cancellations'),
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: colors.map((c) {
        return Container(
          width: 140,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: c.$2,
                  borderRadius: AppRadius.radiusSm,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              AppSpacing.gapVerticalSm,
              Text(
                c.$1,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                c.$3,
                style: AppTypography.small.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypographySection(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVar = theme.colorScheme.onSurfaceVariant;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Display (32px w700)',
            style: AppTypography.display.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'Heading 1 (28px w700)',
            style: AppTypography.h1.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'Heading 2 (24px w600)',
            style: AppTypography.h2.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'Heading 3 (20px w600)',
            style: AppTypography.h3.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'Title (18px w600)',
            style: AppTypography.title.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'Body Large (16px w400) — Smooth readable paragraphs for POS workflows.',
            style: AppTypography.bodyLarge.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'Body (14px w400) — Standard body text with safe line heights.',
            style: AppTypography.body.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'Label (13px w500) — Button & input label text.',
            style: AppTypography.label.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'Small (11.5px w400) — Secondary metadata and badge captions.',
            style: AppTypography.small.copyWith(color: onSurfaceVar),
          ),
          const Divider(height: AppSpacing.xxl),
          // Khmer Script Showcase
          Text(
            'Khmer Language Support (អក្សរខ្មែរ)',
            style: AppTypography.title.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalSm,
          Text(
            'ការគ្រប់គ្រងហាងកាហ្វេ (Coffee Management System)',
            style: AppTypography.h2.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalXs,
          Text(
            'សូមស្វាគមន៍មកកាន់ប្រព័ន្ធគ្រប់គ្រងការលក់កាហ្វេទំនើប • បញ្ជាទិញរហ័ស និងទូទាត់ប្រាក់ប្រកបដោយទំនុកចិត្ត',
            style: AppTypography.bodyLarge.copyWith(color: onSurface),
          ),
          AppSpacing.gapVerticalXs,
          Text(
            'តុលេខ ១ • កាហ្វេទឹកដោះគោទឹកកក ២ កែវ • សរុប: \$4.50',
            style: AppTypography.body.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSection(
    BuildContext context,
    CafeThemeExtension cafeExt,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Total (formatCents)',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapVerticalXs,
                Text(
                  Formatters.formatCents(1250),
                  style: AppTypography.priceLarge.copyWith(
                    color: cafeExt.priceColor,
                  ),
                ),
                AppSpacing.gapVerticalXs,
                Text(
                  'Input: 1250 cents → \$12.50',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapHorizontalMd,
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Revenue KPI',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapVerticalXs,
                Text(
                  Formatters.formatCents(148525),
                  style: AppTypography.kpi.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                AppSpacing.gapVerticalXs,
                Text(
                  '148,525 cents → \$1,485.25',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapHorizontalMd,
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory (formatExactQuantity)',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapVerticalXs,
                Text(
                  Formatters.formatExactQuantity('25.5000', 'kg'),
                  style: AppTypography.h2.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                AppSpacing.gapVerticalXs,
                Text(
                  'Raw: "25.5000" → 25.5 kg',
                  style: AppTypography.small.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonsSection(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(
                label: 'Confirm Order ($_counter)',
                leadingIcon: Icons.check_circle_outline,
                onPressed: () => setState(() => _counter++),
              ),
              AppButton(
                label: 'Add to Ticket',
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.add_shopping_cart,
                onPressed: () {},
              ),
              AppButton(
                label: 'Filter Menu',
                variant: AppButtonVariant.outline,
                leadingIcon: Icons.filter_alt_outlined,
                onPressed: () {},
              ),
              AppButton(
                label: 'Void Item',
                variant: AppButtonVariant.destructive,
                leadingIcon: Icons.delete_outline,
                onPressed: () {},
              ),
              AppButton(
                label: 'View History',
                variant: AppButtonVariant.text,
                onPressed: () {},
              ),
            ],
          ),
          AppSpacing.gapVerticalLg,
          Text(
            'Button States (Disabled & Loading)',
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          AppSpacing.gapVerticalSm,
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const AppButton(label: 'Disabled Primary', onPressed: null),
              const AppButton(
                label: 'Disabled Outline',
                variant: AppButtonVariant.outline,
                onPressed: null,
              ),
              AppButton(label: 'Processing', isLoading: true, onPressed: () {}),
              AppButton(
                label: 'Loading Outline',
                variant: AppButtonVariant.outline,
                isLoading: true,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputsSection(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'Cashier / Barista Name',
            controller: _textController,
            hintText: 'Enter name or ID',
            prefixIcon: const Icon(Icons.person_outline),
          ),
          AppSpacing.gapVerticalMd,
          const AppTextField(
            label: 'Order Reference',
            hintText: 'ORD-01JN3K...',
            helperText: 'Unique ULID-based public ticket reference.',
            prefixIcon: Icon(Icons.receipt_long_outlined),
          ),
          AppSpacing.gapVerticalMd,
          const AppTextField(
            label: 'Discount Code',
            hintText: 'PROMO2026',
            errorText: 'Promotion code has expired or is invalid.',
            prefixIcon: Icon(Icons.local_offer_outlined),
          ),
          AppSpacing.gapVerticalMd,
          const AppTextField(
            label: 'Locked Register ID',
            hintText: 'REG-PHNOM-PENH-01',
            enabled: false,
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Square Badges',
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          AppSpacing.gapVerticalSm,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              StatusBadge(
                label: 'PAID',
                variant: StatusBadgeVariant.success,
                icon: Icons.check_circle_outline,
              ),
              StatusBadge(
                label: 'LOW STOCK',
                variant: StatusBadgeVariant.warning,
                icon: Icons.warning_amber_rounded,
              ),
              StatusBadge(
                label: 'FAILED',
                variant: StatusBadgeVariant.error,
                icon: Icons.error_outline,
              ),
              StatusBadge(
                label: 'PENDING',
                variant: StatusBadgeVariant.information,
                icon: Icons.hourglass_empty,
              ),
              StatusBadge(
                label: 'DRAFT',
                variant: StatusBadgeVariant.neutral,
                icon: Icons.edit_note,
              ),
            ],
          ),
          AppSpacing.gapVerticalLg,
          Text(
            'Pill Badges',
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          AppSpacing.gapVerticalSm,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              StatusBadge(
                label: 'Active Staff',
                variant: StatusBadgeVariant.success,
                isPill: true,
              ),
              StatusBadge(
                label: 'Reorder Needed',
                variant: StatusBadgeVariant.warning,
                isPill: true,
              ),
              StatusBadge(
                label: 'Voided',
                variant: StatusBadgeVariant.error,
                isPill: true,
              ),
              StatusBadge(
                label: 'External QR',
                variant: StatusBadgeVariant.information,
                isPill: true,
              ),
              StatusBadge(
                label: 'Archived',
                variant: StatusBadgeVariant.neutral,
                isPill: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSurfacesSection(
    BuildContext context,
    CafeThemeExtension cafeExt,
  ) {
    return Column(
      children: [
        AppCard(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Card tapped! Ink ripple triggered successfully.',
                ),
                duration: Duration(milliseconds: 1500),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cafeExt.positiveSurface,
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Icon(
                  Icons.receipt_rounded,
                  color: cafeExt.positiveOnSurface,
                ),
              ),
              AppSpacing.gapHorizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interactive Ticket Card (Tap to test ink ripple)',
                      style: AppTypography.title.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    AppSpacing.gapVerticalXs,
                    Text(
                      'Order #ORD-01JN3K79 • 2 items • Dine-in Table 4',
                      style: AppTypography.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.formatCents(650),
                style: AppTypography.price.copyWith(color: cafeExt.priceColor),
              ),
            ],
          ),
        ),
        AppSpacing.gapVerticalLg,
        const AppEmptyState(
          icon: Icons.coffee_rounded,
          title: 'No Active Orders in Queue',
          description:
              'New customer orders taken from the POS terminal will appear here in real time.',
        ),
      ],
    );
  }
}
