// Platform packaging of the owner-supplied logo kit. No geometry is redrawn.
// Run from apps/mobile: flutter test tool/luna_asset_export_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const kit = '../../design/Luna_Cafe_Vector_Logo_Kit/png';

Future<ui.Image> source(String name) async {
  final codec = await ui.instantiateImageCodec(
    await File('$kit/$name').readAsBytes(),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<void> png(
  String file,
  ui.Image original,
  int size, {
  Color? background,
  Color? tint,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (background != null) canvas.drawColor(background, BlendMode.src);
  final paint = Paint()..filterQuality = FilterQuality.high;
  if (tint != null) paint.colorFilter = ColorFilter.mode(tint, BlendMode.srcIn);
  canvas.drawImageRect(
    original,
    Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    paint,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = background == null
      ? (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List()
      : await opaquePng(image, size);
  final target = File(file);
  await target.parent.create(recursive: true);
  await target.writeAsBytes(bytes);
  image.dispose();
  picture.dispose();
}

// RGB encoding removes the alpha channel required to be absent on iOS icons.
// Artwork is resampled/composited for packaging; its geometry remains intact.
Future<Uint8List> opaquePng(ui.Image image, int size) async {
  final rgba = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final rows = Uint8List(size * (size * 3 + 1));
  var output = 0;
  for (var y = 0; y < size; y++) {
    rows[output++] = 0;
    for (var x = 0; x < size; x++) {
      final input = (y * size + x) * 4;
      if (rgba[input + 3] != 255) throw StateError('Icon is not opaque');
      rows[output++] = rgba[input];
      rows[output++] = rgba[input + 1];
      rows[output++] = rgba[input + 2];
    }
  }
  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  final result = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    var crc = 0xffffffff;
    for (final byte in body) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
      }
    }
    result
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(body)
      ..add((ByteData(4)..setUint32(0, crc ^ 0xffffffff)).buffer.asUint8List());
  }

  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibCodec().encode(rows));
  chunk('IEND', []);
  return result.takeBytes();
}

void main() {
  testWidgets('package supplied logo kit without reconstructing geometry', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final mappings = <String, String>{
        'logo_stacked_transparent_1200x1390.png':
            'logo_stacked_transparent.png',
        'monogram_gold_transparent_512x512.png': 'monogram_gold.png',
        'monogram_espresso_transparent_1024x1024.png': 'monogram_espresso.png',
      };
      await Directory('assets/branding').create(recursive: true);
      for (final entry in mappings.entries) {
        await File('$kit/${entry.key}').copy('assets/branding/${entry.value}');
      }
      await File('assets/branding/manifest.json').writeAsString(
        '${const JsonEncoder.withIndent('  ').convert({
          'source': 'design/Luna_Cafe_Vector_Logo_Kit',
          'selection': 'Owner requested supplied kit on 2026-10-15',
          'geometry': 'Unmodified supplied PNG equivalents of the original SVG masters',
          'rights': 'Owner-supplied commissioned project artwork; see kit guides/README.md',
          'files': mappings.entries.map((entry) => {'source': 'png/${entry.key}', 'runtime': entry.value}).toList(),
        })}\n',
      );
      final icon = await source('app_icon_square_dark_1024x1024.png');
      final foreground = await source(
        'android_foreground_monogram_1024x1024.png',
      );
      final light = await source('monogram_espresso_transparent_1024x1024.png');
      final dark = await source('monogram_gold_transparent_512x512.png');
      const coffee = Color(0xFF2B1B0F);
      await png(
        '../../design/luna-cafe/artwork/supplied-kit/icon-1024.png',
        icon,
        1024,
        background: coffee,
      );
      for (final density in <String, int>{
        'mdpi': 1,
        'hdpi': 2,
        'xhdpi': 3,
        'xxhdpi': 4,
        'xxxhdpi': 5,
      }.entries) {
        final launcher = [48, 72, 96, 144, 192][density.value - 1];
        final adaptive = [108, 162, 216, 324, 432][density.value - 1];
        final splash = [96, 144, 192, 288, 384][density.value - 1];
        final res = 'android/app/src/main/res';
        await png(
          '$res/mipmap-${density.key}/ic_launcher.png',
          icon,
          launcher,
          background: coffee,
        );
        await png(
          '$res/drawable-${density.key}/luna_adaptive_foreground.png',
          foreground,
          adaptive,
        );
        await png(
          '$res/drawable-${density.key}/luna_adaptive_monochrome.png',
          foreground,
          adaptive,
          tint: Colors.white,
        );
        await png(
          '$res/drawable-${density.key}/luna_splash_mark.png',
          light,
          splash,
        );
        await png(
          '$res/drawable-night-${density.key}/luna_splash_mark.png',
          dark,
          splash,
        );
      }
      const icons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final manifest =
          jsonDecode(await File('$icons/Contents.json').readAsString())
              as Map<String, dynamic>;
      for (final entry
          in (manifest['images'] as List).cast<Map<String, dynamic>>()) {
        final size =
            (double.parse((entry['size'] as String).split('x').first) *
                    int.parse((entry['scale'] as String)[0]))
                .round();
        await png(
          '$icons/${entry['filename']}',
          icon,
          size,
          background: coffee,
        );
      }
      for (var scale = 1; scale <= 3; scale++) {
        final suffix = scale == 1 ? '' : '@${scale}x';
        await png(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
          light,
          96 * scale,
        );
        await png(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage-dark$suffix.png',
          dark,
          96 * scale,
        );
      }
      icon.dispose();
      foreground.dispose();
      light.dispose();
      dark.dispose();
    });
  });
}
