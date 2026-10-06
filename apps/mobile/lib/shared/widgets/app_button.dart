import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_loading_indicator.dart';

enum AppButtonVariant { primary, secondary, outline, destructive, text }

/// Reusable accessible button conforming to the Premium Café OS design tokens.
///
/// Ensures a minimum 48x48 touch target, distinct visual states for default,
/// pressed, disabled, and loading, and built-in screen reader semantics.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isFullWidth;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine colors based on variant
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
      case AppButtonVariant.secondary:
        backgroundColor = colorScheme.secondary;
        foregroundColor = colorScheme.onSecondary;
      case AppButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = colorScheme.onSurface;
        borderSide = BorderSide(color: colorScheme.outline);
      case AppButtonVariant.destructive:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
      case AppButtonVariant.text:
        backgroundColor = Colors.transparent;
        foregroundColor = colorScheme.primary;
    }

    final buttonStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(
        Size(
          isFullWidth ? double.infinity : AppSpacing.huge,
          AppSpacing.minTouchTarget,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return variant == AppButtonVariant.outline ||
                  variant == AppButtonVariant.text
              ? Colors.transparent
              : colorScheme.outlineVariant.withValues(alpha: 0.5);
        }
        return backgroundColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
        }
        return foregroundColor;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foregroundColor.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return foregroundColor.withValues(alpha: 0.08);
        }
        return null;
      }),
      elevation: WidgetStateProperty.all(0),
      side: WidgetStateProperty.resolveWith((states) {
        if (borderSide == null) return null;
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: colorScheme.outlineVariant);
        }
        return borderSide;
      }),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      textStyle: WidgetStateProperty.all(
        AppTypography.label.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    Widget content;
    if (isLoading) {
      content = AppLoadingIndicator(
        size: 20.0,
        color:
            variant == AppButtonVariant.outline ||
                variant == AppButtonVariant.text
            ? colorScheme.primary
            : foregroundColor,
      );
    } else {
      content = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 18.0),
            AppSpacing.gapHorizontalSm,
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (trailingIcon != null) ...[
            AppSpacing.gapHorizontalSm,
            Icon(trailingIcon, size: 18.0),
          ],
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: label,
      child: ElevatedButton(
        onPressed: _isEnabled ? onPressed : null,
        style: buttonStyle,
        child: content,
      ),
    );
  }
}
