import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Service to abstract platform-specific checks.
class PlatformService {
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isMacOS => !kIsWeb && Platform.isMacOS;
  bool get isLinux => !kIsWeb && Platform.isLinux;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  bool get isDesktop => isMacOS || isLinux || isWindows;
  bool get isMobile => isAndroid || isIOS;
}

// Global instance or provide via Riverpod
final platformService = PlatformService();
