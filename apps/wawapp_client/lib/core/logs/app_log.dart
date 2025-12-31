import 'package:flutter/foundation.dart';

/// Simple logging utility for debugging
class AppLog {
  static final List<String> _logs = [];
  static const int maxLogs = 100;

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';

    _logs.add(logEntry);
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }

    // Print in debug mode only
    if (kDebugMode) {
      print(logEntry);
    }
  }

  static List<String> getLogs() => List.unmodifiable(_logs);

  static void clear() => _logs.clear();
}
