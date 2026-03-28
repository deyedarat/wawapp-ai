import 'package:flutter/foundation.dart';
import 'debug_config.dart';

class WawLog {
  static void d(String tag, String message) {
    if (DebugConfig.enableVerboseLogging) {
      debugPrint('[$tag][DEBUG] $message');
    }
  }

  static void w(String tag, String message) {
    if (DebugConfig.enableVerboseLogging) {
      debugPrint('[$tag][WARN] $message');
    }
  }

  static void e(String tag, String message,
      [Object? error, StackTrace? stack]) {
    debugPrint('[$tag][ERROR] $message');
    if (error != null) {
      debugPrint('[$tag][ERROR] Error: $error');
    }
    if (stack != null) {
      debugPrint('[$tag][ERROR] Stack: $stack');
    }

    if (DebugConfig.enableNonFatalCrashlytics && error != null) {
      _sendToCrashlytics(tag, message, error, stack);
    }
  }

  static void _sendToCrashlytics(
      String tag, String message, Object error, StackTrace? stack) {
    try {
      // Dynamic import to avoid hard dependency
      // Will be initialized in crashlytics_observer.dart
      final crashlytics = _crashlyticsInstance;
      if (crashlytics != null) {
        crashlytics.recordError(error, stack,
            reason: '[$tag] $message', fatal: false);
      }
    } catch (_) {}
  }

  static dynamic _crashlyticsInstance;

  static void setCrashlyticsInstance(dynamic instance) {
    _crashlyticsInstance = instance;
  }
}
