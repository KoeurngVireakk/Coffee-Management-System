import 'package:coffee_management_mobile/features/preview/presentation/design_system_preview_page.dart';
import 'package:coffee_management_mobile/shared/theme/app_breakpoints.dart';
import 'package:coffee_management_mobile/shared/theme/app_spacing.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppBreakpoints unit logic', () {
    testWidgets('identifies compact, medium, and expanded viewports', (
      tester,
    ) async {
      late AppBreakpoint breakpoint;

      Widget buildTest(Size size) {
        return MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Builder(
              builder: (context) {
                breakpoint = AppBreakpoints.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      // Compact: < 600
      await tester.pumpWidget(buildTest(const Size(390, 844)));
      expect(breakpoint, equals(AppBreakpoint.compact));

      // Medium: 600..899
      await tester.pumpWidget(buildTest(const Size(768, 1024)));
      expect(breakpoint, equals(AppBreakpoint.medium));

      // Expanded: >= 900
      await tester.pumpWidget(buildTest(const Size(1280, 800)));
      expect(breakpoint, equals(AppBreakpoint.expanded));
    });

    testWidgets('responsive selector picks correct value per breakpoint', (
      tester,
    ) async {
      late String result;

      Widget buildTest(Size size) {
        return MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Builder(
              builder: (context) {
                result = AppBreakpoints.responsive<String>(
                  context,
                  compact: 'COMPACT',
                  medium: 'MEDIUM',
                  expanded: 'EXPANDED',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTest(const Size(400, 800)));
      expect(result, equals('COMPACT'));

      await tester.pumpWidget(buildTest(const Size(700, 800)));
      expect(result, equals('MEDIUM'));

      await tester.pumpWidget(buildTest(const Size(1000, 800)));
      expect(result, equals('EXPANDED'));
    });

    testWidgets('horizontalPadding adapts to breakpoint', (tester) async {
      late double padding;

      Widget buildTest(Size size) {
        return MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Builder(
              builder: (context) {
                padding = AppBreakpoints.horizontalPadding(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTest(const Size(390, 844)));
      expect(padding, equals(AppSpacing.screenPaddingMobile));

      await tester.pumpWidget(buildTest(const Size(768, 1024)));
      expect(padding, equals(AppSpacing.screenPaddingTablet));

      await tester.pumpWidget(buildTest(const Size(1280, 800)));
      expect(padding, equals(AppSpacing.xxxl));
    });
  });

  group('DesignSystemPreviewPage responsive & accessibility mounting', () {
    testWidgets('mounts cleanly on mobile viewport (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const DesignSystemPreviewPage(themeMode: ThemeMode.light),
        ),
      );
      await tester.pump();

      expect(find.text('Coffee Management System'), findsOneWidget);
      expect(find.text('Confirm Order (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mounts cleanly on tablet viewport (768x1024)', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const DesignSystemPreviewPage(themeMode: ThemeMode.light),
        ),
      );
      await tester.pump();

      expect(find.text('Coffee Management System'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mounts cleanly on POS desktop viewport (1280x800)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const DesignSystemPreviewPage(themeMode: ThemeMode.light),
        ),
      );
      await tester.pump();

      expect(find.text('Coffee Management System'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supports large text scale factor (1.5x) without crashes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 1200),
            textScaler: TextScaler.linear(1.5),
          ),
          child: MaterialApp(
            theme: AppTheme.buildLightTheme(),
            home: const DesignSystemPreviewPage(themeMode: ThemeMode.light),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Coffee Management System'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggles between light and dark mode interactively', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var mode = ThemeMode.light;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: AppTheme.buildLightTheme(),
              darkTheme: AppTheme.buildDarkTheme(),
              themeMode: mode,
              home: DesignSystemPreviewPage(
                themeMode: mode,
                onToggleTheme: () {
                  setState(() {
                    mode = mode == ThemeMode.light
                        ? ThemeMode.dark
                        : ThemeMode.light;
                  });
                },
              ),
            );
          },
        ),
      );
      await tester.pump();

      // Find theme toggle button by tooltip
      final toggleFinder = find.byTooltip('Switch to Dark Mode');
      expect(toggleFinder, findsOneWidget);

      // Tap to toggle to dark mode
      await tester.tap(toggleFinder);
      await tester.pump();

      // Tooltip should now indicate option to switch to light mode
      expect(find.byTooltip('Switch to Light Mode'), findsOneWidget);
    });
  });
}
