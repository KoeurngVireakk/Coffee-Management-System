import 'package:coffee_management_mobile/shared/theme/app_colors.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:coffee_management_mobile/shared/theme/cafe_theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('buildLightTheme configures Material 3 and brand tokens', () {
      final theme = AppTheme.buildLightTheme();

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.colorScheme.primary, equals(AppColors.espresso));
      expect(theme.colorScheme.secondary, equals(AppColors.forestGreen));
      expect(theme.colorScheme.tertiary, equals(AppColors.caramel));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.warmCream));

      final cafeExt = theme.extension<CafeThemeExtension>();
      expect(cafeExt, isNotNull);
      expect(cafeExt!.positiveSurface, equals(AppColors.successSurfaceLight));
      expect(cafeExt.positiveOnSurface, equals(AppColors.successLight));
      expect(cafeExt.priceColor, equals(AppColors.espresso));
    });

    test('buildDarkTheme configures Material 3 and dark tokens', () {
      final theme = AppTheme.buildDarkTheme();

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.darkBackground));
      expect(theme.colorScheme.surface, equals(AppColors.darkSurface));

      final cafeExt = theme.extension<CafeThemeExtension>();
      expect(cafeExt, isNotNull);
      expect(cafeExt!.positiveSurface, equals(AppColors.successSurfaceDark));
      expect(cafeExt.positiveOnSurface, equals(AppColors.successDark));
      expect(cafeExt.priceColor, equals(AppColors.darkPrimaryWarm));
    });

    test('CafeThemeExtension supports copyWith and lerp', () {
      const original = CafeThemeExtension.light;
      final modified = original.copyWith(positiveSurface: Colors.cyan);
      expect(modified.positiveSurface, equals(Colors.cyan));
      expect(modified.positiveOnSurface, equals(original.positiveOnSurface));

      final lerped = original.lerp(modified, 0.5);
      expect(lerped, isNotNull);

      // lerping with null returns this
      final lerpWithNull = original.lerp(null, 0.5);
      expect(lerpWithNull, equals(original));
    });

    testWidgets('CafeThemeExtension.of retrieves extension from context', (
      tester,
    ) async {
      late CafeThemeExtension foundExt;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Builder(
            builder: (context) {
              foundExt = CafeThemeExtension.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(foundExt.priceColor, equals(AppColors.espresso));
    });
  });
}
