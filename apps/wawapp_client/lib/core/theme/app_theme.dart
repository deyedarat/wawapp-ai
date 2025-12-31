/// WawApp Theme System (legacy compatibility wrapper)
///
/// This file maintains backward compatibility with existing code
/// while delegating to the new comprehensive theme system.
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart' as new_theme;

/// Legacy AppTheme class for backward compatibility
/// Delegates to the new WawAppTheme system
class AppTheme {
  AppTheme._();

  // Legacy color constants (kept for backward compatibility)
  static const Color primaryColor =
      Color(0xFF006AFF); // Updated to match new theme
  static const Color secondaryColor = Color(0xFFFFC727); // Golden Yellow
  static const Color errorColor = Color(0xFFE74C3C); // Deep Red
  static const Color darkSurface = Color(0xFF1D1D1D); // Dark Background

  /// Light theme - delegates to new theme system
  static ThemeData get lightTheme => new_theme.WawAppTheme.light();

  /// Dark theme - delegates to new theme system
  static ThemeData get darkTheme => new_theme.WawAppTheme.dark();
}
