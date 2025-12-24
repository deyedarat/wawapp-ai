import 'package:flutter/foundation.dart';

/// Test Lab configuration flags for Firebase Test Lab integration
class TestLabFlags {
  /// Whether Test Lab mode is enabled via --dart-define=TEST_LAB=true
  static const bool enabled = bool.fromEnvironment('TEST_LAB', defaultValue: false);
  
  /// Safe version that prevents accidental activation in release builds
  static bool get safeEnabled => enabled && !kReleaseMode;
}