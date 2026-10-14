import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:coffee_management_mobile/shared/widgets/app_button.dart';
import 'package:coffee_management_mobile/shared/widgets/app_card.dart';
import 'package:coffee_management_mobile/shared/widgets/app_feedback_banner.dart';
import 'package:coffee_management_mobile/shared/widgets/app_metric_card.dart';
import 'package:coffee_management_mobile/shared/widgets/app_quantity_stepper.dart';
import 'package:coffee_management_mobile/shared/widgets/app_search_field.dart';
import 'package:coffee_management_mobile/shared/widgets/app_skeleton_card.dart';
import 'package:coffee_management_mobile/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCard Modernization', () {
    testWidgets('renders with elevation and custom shadow without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: AppCard(
              elevation: 2.0,
              child: Text('Elevated Card'),
            ),
          ),
        ),
      );

      expect(find.text('Elevated Card'), findsOneWidget);
    });
  });

  group('AppButton Size Variant', () {
    testWidgets('renders large size button with full width', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppButton(
              label: 'Pay Now',
              size: AppButtonSize.large,
              isFullWidth: true,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Pay Now'), findsOneWidget);
      await tester.tap(find.text('Pay Now'));
      await tester.pump();
      expect(pressed, isTrue);
    });
  });

  group('AppMetricCard', () {
    testWidgets('renders KPI label, tabular value, badge and subtitle', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppMetricCard(
              label: 'Today Revenue',
              value: '\$1,245.50',
              subtitle: '45 completed orders',
              badgeLabel: '+14%',
              badgeVariant: StatusBadgeVariant.success,
              icon: Icons.payments_rounded,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Today Revenue'), findsOneWidget);
      expect(find.text('\$1,245.50'), findsOneWidget);
      expect(find.text('45 completed orders'), findsOneWidget);
      expect(find.text('+14%'), findsOneWidget);
      expect(find.byIcon(Icons.payments_rounded), findsOneWidget);

      await tester.tap(find.text('Today Revenue'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('AppSearchField', () {
    testWidgets('handles typing, shows clear button, and clears text', (tester) async {
      String changedText = '';
      var cleared = false;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppSearchField(
              controller: controller,
              hintText: 'Search products...',
              onChanged: (val) => changedText = val,
              onClear: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.text('Search products...'), findsOneWidget);
      expect(find.byIcon(Icons.clear_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'Espresso');
      await tester.pump();

      expect(changedText, 'Espresso');
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      expect(controller.text, '');
      expect(cleared, isTrue);
    });
  });

  group('AppQuantityStepper', () {
    testWidgets('increments and decrements within boundaries', (tester) async {
      var count = 2;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: AppTheme.buildLightTheme(),
              home: Scaffold(
                body: AppQuantityStepper(
                  value: count,
                  min: 1,
                  max: 5,
                  onIncrement: () => setState(() => count++),
                  onDecrement: () => setState(() => count--),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('2'), findsOneWidget);

      // Decrement
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(count, 1);
      expect(find.text('1'), findsOneWidget);

      // Try decrementing below min
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(count, 1); // unreached

      // Increment
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(count, 2);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('AppFeedbackBanner', () {
    testWidgets('renders all banner variants and handles action and dismiss', (tester) async {
      var actionFired = false;
      var dismissed = false;

      for (final variant in FeedbackBannerVariant.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildLightTheme(),
            home: Scaffold(
              body: AppFeedbackBanner(
                title: 'Notice',
                message: 'This is a ${variant.name} banner',
                variant: variant,
                actionLabel: 'Details',
                onAction: () => actionFired = true,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        );

        expect(find.text('Notice'), findsOneWidget);
        expect(find.text('This is a ${variant.name} banner'), findsOneWidget);
      }

      await tester.tap(find.text('Details'));
      await tester.pump();
      expect(actionFired, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  group('AppSkeletonCard', () {
    testWidgets('renders pulsing skeleton card without exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: AppSkeletonCard(),
          ),
        ),
      );

      expect(find.byType(AppSkeletonCard), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}

