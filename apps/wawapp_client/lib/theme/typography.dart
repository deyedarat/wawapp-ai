/// Typography system for WawApp Client
/// Defines text styles for both Arabic and French with proper RTL/LTR support
library;

import 'package:flutter/material.dart';
import 'colors.dart';

/// WawApp Typography System
/// 
/// Uses system fonts optimized for Arabic and French:
/// - Arabic: System default (typically includes Arabic support)
/// - French: System default (Latin script)
/// 
/// If Google Fonts are added later, use Cairo or Noto Sans Arabic
class WawAppTypography {
  WawAppTypography._();

  /// Font family - using system default for now
  /// To use Google Fonts, add to pubspec.yaml and import:
  /// ```dart
  /// import 'package:google_fonts/google_fonts.dart';
  /// static const String fontFamily = 'Cairo'; // or 'NotoSansArabic'
  /// ```
  static const String fontFamily = ''; // System default

  /// Light Theme Text Theme
  static TextTheme lightTextTheme = TextTheme(
    // Display styles (largest)
    displayLarge: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
      height: 1.2,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),
    displayMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.25,
      height: 1.3,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),
    displaySmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),

    // Title styles
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),

    // Body styles (main content)
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      height: 1.5,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      height: 1.5,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      height: 1.5,
      color: WawAppColors.textSecondaryLight,
      fontFamily: fontFamily,
    ),

    // Label styles (buttons, labels)
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.4,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.4,
      color: WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
      color: WawAppColors.textSecondaryLight,
      fontFamily: fontFamily,
    ),
  );

  /// Dark Theme Text Theme
  static TextTheme darkTextTheme = TextTheme(
    // Display styles (largest)
    displayLarge: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
      height: 1.2,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),
    displayMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.25,
      height: 1.3,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),
    displaySmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),

    // Title styles
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),

    // Body styles (main content)
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      height: 1.5,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      height: 1.5,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      height: 1.5,
      color: WawAppColors.textSecondaryDark,
      fontFamily: fontFamily,
    ),

    // Label styles (buttons, labels)
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.4,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.4,
      color: WawAppColors.textPrimaryDark,
      fontFamily: fontFamily,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
      color: WawAppColors.textSecondaryDark,
      fontFamily: fontFamily,
    ),
  );

  /// Helper method to get text style with custom color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Helper method to adjust font weight
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Helper method to adjust font size
  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }

  /// Badge text style
  static TextStyle badge({Color? color}) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.2,
      color: color ?? WawAppColors.textPrimaryLight,
      fontFamily: fontFamily,
    );
  }
}

/// Typography extension for BuildContext
extension TypographyExtension on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  
  // Quick access to common text styles
  TextStyle? get displayLarge => textTheme.displayLarge;
  TextStyle? get displayMedium => textTheme.displayMedium;
  TextStyle? get titleLarge => textTheme.titleLarge;
  TextStyle? get titleMedium => textTheme.titleMedium;
  TextStyle? get titleSmall => textTheme.titleSmall;
  TextStyle? get bodyLarge => textTheme.bodyLarge;
  TextStyle? get bodyMedium => textTheme.bodyMedium;
  TextStyle? get bodySmall => textTheme.bodySmall;
  TextStyle? get labelLarge => textTheme.labelLarge;
  TextStyle? get labelMedium => textTheme.labelMedium;
}
