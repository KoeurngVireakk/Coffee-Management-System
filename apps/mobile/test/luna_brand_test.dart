import 'dart:math' as math;

import 'package:coffee_management_mobile/core/network/api_exception.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:coffee_management_mobile/features/auth/presentation/login_page.dart';
import 'package:coffee_management_mobile/shared/brand/luna_brand.dart';
import 'package:coffee_management_mobile/shared/theme/app_colors.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:coffee_management_mobile/shared/theme/app_typography.dart';
import 'package:coffee_management_mobile/shared/theme/cafe_theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_controller_test.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + .05) / (math.min(first, second) + .05);
}

void main() {
  setUpAll(() async {
    // Test with the shipped fonts, rather than the tester's Ahem placeholder.
    for (final font in <String, String>{
      'Inter': 'inter/Inter.ttf',
      'Noto Sans Khmer': 'notosanskhmer/NotoSansKhmer.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
  });

  test('brand foregrounds and semantic messages retain readable contrast', () {
    for (final theme in [
      AppTheme.buildLightTheme(),
      AppTheme.buildDarkTheme(),
    ]) {
      final scheme = theme.colorScheme;
      final extension = theme.extension<CafeThemeExtension>()!;
      for (final pair in [
        (scheme.onSurface, scheme.surface),
        (scheme.onSurfaceVariant, theme.scaffoldBackgroundColor),
        (scheme.onPrimary, scheme.primary),
        (scheme.onSecondary, scheme.secondary),
        (scheme.onTertiary, scheme.tertiary),
        (extension.onAccentCaramel, extension.accentCaramel),
        (extension.positiveOnSurface, extension.positiveSurface),
        (extension.errorOnSurface, extension.errorSurface),
        (extension.warningOnSurface, extension.warningSurface),
        (extension.infoOnSurface, extension.infoSurface),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      expect(
        {
          extension.positiveOnSurface,
          extension.errorOnSurface,
          extension.warningOnSurface,
          extension.infoOnSurface,
        }.length,
        4,
      );
    }
    expect(
      contrast(AppColors.strongGold, AppColors.warmCream),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      AppTypography.price.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(AppTypography.price.fontFamily, isNot('Playfair Display'));
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(600, 960),
    const Size(768, 1024),
    const Size(1024, 768),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Luna login $size ${dark ? 'dark' : 'light'} ${scale}x with local English/Khmer fonts',
          (tester) async {
            tester.view
              ..physicalSize = size
              ..devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final controller = AuthController(repository: FakeAuthRepository());
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark
                    ? AppTheme.buildDarkTheme()
                    : AppTheme.buildLightTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: LoginPage(authController: controller),
              ),
            );
            await tester.pumpAndSettle();
            final logo = tester.widget<Image>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Image && widget.semanticLabel == LunaBrand.name,
              ),
            );
            await tester.runAsync(
              () => precacheImage(
                logo.image,
                tester.element(find.byType(LunaBrandLockup)),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<RawImage>(
                    find.descendant(
                      of: find.byType(LunaBrandLockup),
                      matching: find.byType(RawImage),
                    ),
                  )
                  .image,
              isNotNull,
            );
            expect(find.byType(LunaBrandLockup), findsOneWidget);
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Image && widget.semanticLabel == LunaBrand.name,
              ),
              findsOneWidget,
            );
            expect(find.text('ប្រព័ន្ធគ្រប់គ្រងហាងកាហ្វេ'), findsOneWidget);
            await tester.ensureVisible(find.text('Sign In'));
            final button = find.byType(ElevatedButton);
            expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
            await tester.tap(find.text('Sign In'));
            await tester.pumpAndSettle();
            expect(find.text('Email is required.'), findsOneWidget);
            expect(find.text('Password is required.'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  testWidgets(
    'branded login keeps timeout feedback and retry reachable at 2x',
    (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AuthController(
        repository: FakeAuthRepository(
          loginHandler: (_, _) async =>
              throw const NetworkException('Request timed out'),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: LoginPage(authController: controller),
        ),
      );
      await tester.enterText(
        find.byType(TextField).first,
        'staff@example.test',
      );
      await tester.enterText(find.byType(TextField).last, 'synthetic-password');
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(controller.state, isA<Unauthenticated>());
      final failure = (controller.state as Unauthenticated).failure;
      expect(failure, isNotNull);
      expect(find.text(failure!.userMessage), findsOneWidget);
      await tester.ensureVisible(find.text('Sign In'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
