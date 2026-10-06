import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:coffee_management_mobile/shared/widgets/app_card.dart';
import 'package:coffee_management_mobile/shared/widgets/app_empty_state.dart';
import 'package:coffee_management_mobile/shared/widgets/app_section_header.dart';
import 'package:coffee_management_mobile/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatusBadge', () {
    testWidgets('renders all badge variants without error', (tester) async {
      for (final variant in StatusBadgeVariant.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildLightTheme(),
            home: Scaffold(
              body: StatusBadge(
                label: 'Status ${variant.name}',
                variant: variant,
              ),
            ),
          ),
        );

        expect(find.text('Status ${variant.name}'), findsOneWidget);
      }
    });

    testWidgets('renders with icon and pill shape', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: StatusBadge(label: 'Active', icon: Icons.check, isPill: true),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('contains semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: StatusBadge(
              label: 'Low Stock',
              variant: StatusBadgeVariant.warning,
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Low Stock status',
        ),
        findsOneWidget,
      );
    });
  });

  group('AppCard', () {
    testWidgets('renders child content correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(body: AppCard(child: Text('Card Content'))),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppCard(
              onTap: () => tapped = true,
              child: const Text('Tappable Card'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Card'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('AppEmptyState', () {
    testWidgets('renders icon, title, description, and action', (tester) async {
      var actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.coffee,
              title: 'No Items',
              description: 'Please add items to your cart',
              action: ElevatedButton(
                onPressed: () => actionTapped = true,
                child: const Text('Add Now'),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.coffee), findsOneWidget);
      expect(find.text('No Items'), findsOneWidget);
      expect(find.text('Please add items to your cart'), findsOneWidget);
      expect(find.text('Add Now'), findsOneWidget);

      await tester.tap(find.text('Add Now'));
      await tester.pump();

      expect(actionTapped, isTrue);
    });
  });

  group('AppSectionHeader', () {
    testWidgets('renders title, subtitle, and action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: AppSectionHeader(
              title: 'Orders',
              subtitle: 'Recent daily tickets',
              action: Icon(Icons.more_vert),
            ),
          ),
        ),
      );

      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Recent daily tickets'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });
}
