import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/cafe_theme_extension.dart';

enum FeedbackBannerVariant { info, success, warning, error }

/// Contextual inline notification banner for warnings, confirmations, and alerts.
///
/// Complies with the 60-25-10-5 palette via [CafeThemeExtension] surface tokens,
/// providing high-contrast text and distinct iconography for non-color accessibility.
class AppFeedbackBanner extends StatelessWidget {
  const AppFeedbackBanner({
    super.key,
    required this.message,
    this.variant = FeedbackBannerVariant.info,
    this.title,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final FeedbackBannerVariant variant;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final cafeExt = CafeThemeExtension.of(context);

    Color bg;
    Color fg;
    IconData iconData;

    switch (variant) {
      case FeedbackBannerVariant.success:
        bg = cafeExt.positiveSurface;
        fg = cafeExt.positiveOnSurface;
        iconData = Icons.check_circle_rounded;
      case FeedbackBannerVariant.warning:
        bg = cafeExt.warningSurface;
        fg = cafeExt.warningOnSurface;
        iconData = Icons.warning_amber_rounded;
      case FeedbackBannerVariant.error:
        bg = cafeExt.errorSurface;
        fg = cafeExt.errorOnSurface;
        iconData = Icons.error_outline_rounded;
      case FeedbackBannerVariant.info:
        bg = cafeExt.infoSurface;
        fg = cafeExt.infoOnSurface;
        iconData = Icons.info_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(iconData, size: 20.0, color: fg),
          ),
          AppSpacing.gapHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTypography.label.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppSpacing.gapVerticalXs,
                ],
                Text(
                  message,
                  style: AppTypography.body.copyWith(color: fg, fontSize: 13.5),
                ),
                if (actionLabel != null && onAction != null) ...[
                  AppSpacing.gapVerticalSm,
                  InkWell(
                    onTap: onAction,
                    borderRadius: AppRadius.radiusSm,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        actionLabel!,
                        style: AppTypography.label.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            Semantics(
              button: true,
              label: 'Dismiss banner',
              child: SizedBox(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18.0),
                  color: fg,
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
