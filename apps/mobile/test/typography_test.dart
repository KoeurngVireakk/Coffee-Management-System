import 'package:coffee_management_mobile/shared/theme/app_colors.dart';
import 'package:coffee_management_mobile/shared/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTypography', () {
    test('font fallbacks include Inter and Noto Sans Khmer', () {
      expect(
        AppTypography.fontFallback,
        containsAllInOrder(['Inter', 'Noto Sans Khmer', 'sans-serif']),
      );
    });

    test(
      'line heights maintain safe bounds for Khmer diacritics and subscripts',
      () {
        expect(AppTypography.display.height, greaterThanOrEqualTo(1.3));
        expect(AppTypography.h1.height, greaterThanOrEqualTo(1.35));
        expect(AppTypography.h2.height, greaterThanOrEqualTo(1.35));
        expect(AppTypography.h3.height, greaterThanOrEqualTo(1.4));
        expect(AppTypography.title.height, greaterThanOrEqualTo(1.4));
        expect(AppTypography.bodyLarge.height, greaterThanOrEqualTo(1.45));
        expect(AppTypography.body.height, greaterThanOrEqualTo(1.45));
        expect(AppTypography.label.height, greaterThanOrEqualTo(1.4));
        expect(AppTypography.small.height, greaterThanOrEqualTo(1.35));
      },
    );

    test('numeric price and KPI styles use tabular figures', () {
      const tabular = FontFeature.tabularFigures();

      expect(AppTypography.price.fontFeatures, contains(tabular));
      expect(AppTypography.priceLarge.fontFeatures, contains(tabular));
      expect(AppTypography.kpi.fontFeatures, contains(tabular));
    });

    test('createTextTheme builds full Material 3 text theme', () {
      final textTheme = AppTypography.createTextTheme(
        AppColors.textPrimaryLight,
        AppColors.textSecondaryLight,
      );

      expect(textTheme.displayLarge?.color, equals(AppColors.textPrimaryLight));
      expect(textTheme.bodyLarge?.color, equals(AppColors.textPrimaryLight));
      expect(textTheme.bodySmall?.color, equals(AppColors.textSecondaryLight));
      expect(textTheme.labelSmall?.color, equals(AppColors.textSecondaryLight));
    });

    testWidgets('renders Khmer text without exceptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('ការគ្រប់គ្រងហាងកាហ្វេ', style: AppTypography.h1),
                Text(
                  'សូមស្វាគមន៍មកកាន់ប្រព័ន្ធលក់កាហ្វេ',
                  style: AppTypography.body,
                ),
                Text('តុលេខ ១', style: AppTypography.label),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ការគ្រប់គ្រងហាងកាហ្វេ'), findsOneWidget);
      expect(find.text('សូមស្វាគមន៍មកកាន់ប្រព័ន្ធលក់កាហ្វេ'), findsOneWidget);
      expect(find.text('តុលេខ ១'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
