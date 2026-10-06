import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Lightweight loading indicator conforming to the Premium Café OS aesthetic.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.5,
    this.color,
    this.message,
  });

  final double size;
  final double strokeWidth;
  final Color? color;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
      ),
    );

    if (message == null) {
      return Center(child: indicator);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          AppSpacing.gapVerticalMd,
          Text(
            message!,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

