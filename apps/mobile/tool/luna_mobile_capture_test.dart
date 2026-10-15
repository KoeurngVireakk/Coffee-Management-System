// Native Flutter phone/tablet fixture captures, not golden baselines.
// flutter test tool/luna_mobile_capture_test.dart --reporter expanded
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'luna_audit_preview.dart';

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
  for (final capture in [
    (
      name: 'login-phone-light',
      role: 'login',
      theme: 'light',
      state: 'data',
      size: const Size(390, 844),
      scale: 1.0,
    ),
    (
      name: 'login-phone-dark',
      role: 'login',
      theme: 'dark',
      state: 'data',
      size: const Size(360, 800),
      scale: 1.0,
    ),
    (
      name: 'login-tablet-light',
      role: 'login',
      theme: 'light',
      state: 'data',
      size: const Size(768, 1024),
      scale: 1.0,
    ),
    (
      name: 'login-phone-2x',
      role: 'login',
      theme: 'light',
      state: 'data',
      size: const Size(360, 800),
      scale: 2.0,
    ),
    (
      name: 'pos-phone-light',
      role: 'cashier',
      theme: 'light',
      state: 'data',
      size: const Size(390, 844),
      scale: 1.0,
    ),
    (
      name: 'pos-tablet-dark',
      role: 'cashier',
      theme: 'dark',
      state: 'data',
      size: const Size(1024, 768),
      scale: 1.0,
    ),
    (
      name: 'pos-phone-2x',
      role: 'cashier',
      theme: 'light',
      state: 'data',
      size: const Size(360, 800),
      scale: 2.0,
    ),
    (
      name: 'pos-phone-empty',
      role: 'cashier',
      theme: 'light',
      state: 'empty',
      size: const Size(390, 844),
      scale: 1.0,
    ),
    (
      name: 'pos-phone-error',
      role: 'cashier',
      theme: 'dark',
      state: 'error',
      size: const Size(390, 844),
      scale: 1.0,
    ),
  ]) {
    testWidgets('capture ${capture.name}', (tester) async {
      tester.view
        ..physicalSize = capture.size
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = capture.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final preview = await tester.runAsync(
        () => createAuditPreview(
          requestedRole: capture.role,
          theme: capture.theme,
          mode: capture.state,
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        preview!.dispose();
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: preview!.widget),
      );
      await tester.pumpAndSettle();
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
          '../../design/luna-cafe/previews/phase-8a/${capture.name}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
