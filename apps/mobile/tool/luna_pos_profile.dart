/// Android/iOS profile entrypoint for the read-only POS fixtures, never production.
/// Run with `flutter run --profile -d DEVICE -t tool/luna_pos_profile.dart`.
/// Exercise catalog/cart during the 60-second window; no server writes are possible.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'luna_audit_preview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preview = await createAuditPreview();
  final elapsed = Stopwatch()..start();
  final frames = <FrameTiming>[];
  final warmFrames = <FrameTiming>[];
  void collect(List<FrameTiming> batch) {
    frames.addAll(batch);
    if (elapsed.elapsed >= const Duration(seconds: 5)) warmFrames.addAll(batch);
  }

  SchedulerBinding.instance.addTimingsCallback(collect);
  runApp(
    ColoredBox(
      color: const Color(0xFF2B1B0F),
      child: SafeArea(bottom: false, child: preview.widget),
    ),
  );
  Timer(const Duration(seconds: 60), () {
    SchedulerBinding.instance.removeTimingsCallback(collect);
    Map<String, Object> summary(List<FrameTiming> sample) {
      Map<String, Object> durations(Duration Function(FrameTiming) select) {
        final values =
            sample.map((frame) => select(frame).inMicroseconds).toList()
              ..sort();
        if (values.isEmpty) return {'samples': 0};
        double percentile(double fraction) =>
            values[((values.length - 1) * fraction).ceil()] / 1000;
        return {
          'p50_ms': percentile(.5),
          'p95_ms': percentile(.95),
          'max_ms': values.last / 1000,
        };
      }

      return {
        'frames': sample.length,
        'build': durations((frame) => frame.buildDuration),
        'raster': durations((frame) => frame.rasterDuration),
        'total_span': durations((frame) => frame.totalSpan),
      };
    }

    debugPrint(
      'LUNA_POS_PROFILE ${jsonEncode({'window_seconds': elapsed.elapsed.inMilliseconds / 1000, 'all': summary(frames), 'after_first_5_seconds': summary(warmFrames)})}',
    );
  });
}
