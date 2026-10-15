// Native Flutter phone/tablet fixture captures, not golden baselines.
// flutter test tool/luna_pos_rescue_capture_test.dart --reporter expanded
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'luna_audit_preview.dart';
import 'package:coffee_management_mobile/features/pos/presentation/pos_product_card.dart';

void main() {
  setUpAll(() async {
    for (final font in <String, String>{
      'Inter': 'inter/Inter.ttf',
      'Noto Sans Khmer': 'notosanskhmer/NotoSansKhmer.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final captures =
      <
        ({
          String name,
          String role,
          String theme,
          String state,
          Size size,
          double scale,
          String action,
        })
      >[
        for (final viewport in [
          (name: 'phone', size: const Size(390, 844)),
          (name: 'compact', size: const Size(360, 800)),
          (name: 'tablet-portrait', size: const Size(768, 1024)),
          (name: 'tablet-landscape', size: const Size(1024, 768)),
        ])
          for (final theme in ['light', 'dark'])
            for (final scale in [1.0, 2.0])
              for (final state in ['data', 'empty', 'error'])
                (
                  name: state == 'data'
                      ? 'pos-${viewport.name}-$theme-${scale.toInt()}x'
                      : viewport.name == 'phone' && scale == 1
                      ? 'pos-phone-$state-$theme'
                      : 'pos-${viewport.name}-$state-$theme-${scale.toInt()}x',
                  role: 'cashier',
                  theme: theme,
                  state: state,
                  size: viewport.size,
                  scale: scale,
                  action: '',
                ),
        for (final theme in ['light', 'dark'])
          (
            name: 'pos-phone-loading-$theme',
            role: 'cashier',
            theme: theme,
            state: 'loading',
            size: const Size(390, 844),
            scale: 1.0,
            action: '',
          ),
        (
          name: 'phone-cart',
          role: 'cashier',
          theme: 'light',
          state: 'data',
          size: const Size(390, 844),
          scale: 1.0,
          action: 'cart',
        ),
        (
          name: 'compact-cart-2x',
          role: 'cashier',
          theme: 'dark',
          state: 'data',
          size: const Size(360, 800),
          scale: 2.0,
          action: 'cart',
        ),
        (
          name: 'compact-cart-2x-checkout',
          role: 'cashier',
          theme: 'dark',
          state: 'data',
          size: const Size(360, 800),
          scale: 2.0,
          action: 'cart-end',
        ),
        (
          name: 'tablet-cart',
          role: 'cashier',
          theme: 'dark',
          state: 'data',
          size: const Size(1024, 768),
          scale: 1.0,
          action: 'cart',
        ),
      ];
  for (final capture in captures) {
    testWidgets('capture ${capture.name}', (tester) async {
      tester.view
        ..physicalSize = capture.size
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = capture.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final preview = (await tester.runAsync(
        () => createAuditPreview(
          requestedRole: capture.role,
          theme: capture.theme,
          mode: capture.state,
        ),
      ))!;
      try {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: preview.widget),
        );
        await tester.pumpAndSettle();
        if (capture.action.startsWith('cart')) {
          await tester.tap(find.byType(PosProductCard).first);
          await tester.pumpAndSettle();
          if (find.byKey(const ValueKey('open-cart')).evaluate().isNotEmpty) {
            await tester.tap(find.byKey(const ValueKey('open-cart')));
            await tester.pumpAndSettle();
          }
        }
        if (capture.action == 'cart-end') {
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Checkout'),
          );
          await tester.pumpAndSettle();
        }
        // Asset decoding is real asynchronous work, outside the fake frame clock.
        // Wait for the exact resized providers used by the screen before capture.
        await tester.runAsync(() async {
          for (final widget in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(widget.image, key.currentContext!);
          }
        });
        await tester.pumpAndSettle();
        for (final raw in tester.widgetList<RawImage>(find.byType(RawImage))) {
          expect(
            raw.image,
            isNotNull,
            reason: 'Brand artwork must render in captures',
          );
        }
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '../../design/luna-cafe/previews/phase-8b1/${capture.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        preview.dispose();
        // Dispose before the binding's end-of-test invariants, not in the
        // package:test teardown that runs after those invariants.
        await tester.pump(
          capture.state == 'loading'
              ? const Duration(seconds: 16)
              : Duration.zero,
        );
      }
    });
  }
}
