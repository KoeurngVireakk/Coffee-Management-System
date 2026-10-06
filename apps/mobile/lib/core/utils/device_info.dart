import 'package:flutter/foundation.dart';

/// Provides a human-readable client platform label for Sanctum token registration.
///
/// Strictly complies with privacy guidelines: collects only OS/platform category
/// without collecting hardware serial numbers, IMEIs, MAC addresses, advertising IDs,
/// or device fingerprints. Max length is bounded to 100 characters.
abstract final class DeviceInfo {
  static String getDeviceName() {
    if (kIsWeb) {
      return 'Coffee POS Web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Coffee POS Android';
      case TargetPlatform.iOS:
        return 'Coffee POS iOS';
      case TargetPlatform.macOS:
        return 'Coffee POS macOS';
      case TargetPlatform.windows:
        return 'Coffee POS Windows';
      case TargetPlatform.linux:
        return 'Coffee POS Linux';
      case TargetPlatform.fuchsia:
        return 'Coffee POS Fuchsia';
    }
  }
}
