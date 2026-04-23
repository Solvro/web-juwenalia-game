import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Safe platform helpers — these return false on web (where `Platform` throws).
class PlatformUtils {
  PlatformUtils._();

  static bool get isIOS {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static bool get isMacOS {
    if (kIsWeb) return false;
    try {
      return Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  static bool get isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// "Apple" platforms — iOS or macOS — where translucent / liquid-glass
  /// chrome looks native.
  static bool get isApple => isIOS || isMacOS;

  static bool get isWeb => kIsWeb;
}

/// Layout breakpoints (mirroring Material 3 window-size classes).
class Breakpoints {
  Breakpoints._();

  /// Below this we use the bottom-nav phone layout.
  static const double compact = 600;

  /// Above this we use the desktop sidebar layout with download-app prompt.
  static const double expanded = 900;
}
