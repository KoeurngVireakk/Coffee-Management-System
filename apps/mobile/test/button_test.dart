import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:coffee_management_mobile/shared/widgets/app_button.dart';
import 'package:coffee_management_mobile/shared/widgets/app_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppButton', () {
    testWidgets('renders all variants without error', (tester) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildLightTheme(),
            home: Scaffold(
              body: AppButton(
                label: 'Button ${variant.name}',
                variant: variant,
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Button ${variant.name}'), findsOneWidget);
      }
    });

    testWidgets('enforces minimum 48px touch target height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: Center(
              child: AppButton(label: 'Touch Target Test', onPressed: () {}),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(ElevatedButton);
      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('triggers onPressed callback when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppButton(label: 'Click Me', onPressed: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('Click Me'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('disabled state does not respond to taps', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: AppButton(label: 'Disabled', onPressed: null),
          ),
        ),
      );

      final elevatedBtn = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(elevatedBtn.onPressed, isNull);
    });

    testWidgets('loading state displays AppLoadingIndicator and blocks taps', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppButton(
              label: 'Saving...',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text('Saving...'), findsNothing);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('renders leading and trailing icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppButton(
              label: 'With Icons',
              leadingIcon: Icons.add,
              trailingIcon: Icons.arrow_forward,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('has semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppButton(label: 'Submit Ticket', onPressed: () {}),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Submit Ticket',
        ),
        findsOneWidget,
      );
    });
  });
}
