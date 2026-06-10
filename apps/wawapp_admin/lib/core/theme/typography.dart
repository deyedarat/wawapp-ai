import 'package:flutter/material.dart';
import 'colors.dart';

/// Admin App Typography
/// Uses Tajawal for Arabic (headings & body) — a modern, clean Arabic webfont.
/// Fallback to Inter for Latin characters.
class AdminTypography {
  AdminTypography._();

  // Font families
  // Tajawal: clean Arabic font with proper weight range (300-900)
  // Inter: fallback for Latin/numbers
  static const String primaryFont = 'Tajawal';
  static const String fallbackFont = 'Inter';

  /// Light theme text styles
  static TextTheme lightTextTheme = TextTheme(
    // Display styles (large headings)
    displayLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 52,
      fontWeight: FontWeight.w700,
      color: AdminAppColors.textPrimaryLight,
      height: 1.2,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 42,
      fontWeight: FontWeight.w700,
      color: AdminAppColors.textPrimaryLight,
      height: 1.2,
      letterSpacing: -0.3,
    ),
    displaySmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AdminAppColors.textPrimaryLight,
      height: 1.25,
    ),

    // Headline styles
    headlineLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AdminAppColors.textPrimaryLight,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.35,
    ),
    headlineSmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.35,
    ),

    // Title styles
    titleLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.4,
    ),

    // Body styles
    bodyLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AdminAppColors.textPrimaryLight,
      height: 1.6,
    ),
    bodyMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AdminAppColors.textPrimaryLight,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AdminAppColors.textSecondaryLight,
      height: 1.5,
    ),

    // Label styles
    labelLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AdminAppColors.textPrimaryLight,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AdminAppColors.textPrimaryLight,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AdminAppColors.textSecondaryLight,
      height: 1.4,
    ),
  );

  /// Dark theme text styles
  static TextTheme darkTextTheme = lightTextTheme.apply(
    bodyColor: AdminAppColors.textPrimaryDark,
    displayColor: AdminAppColors.textPrimaryDark,
  );
}

/// Convenient access to text styles (alias for AdminTypography)
class AdminAppTextStyles {
  AdminAppTextStyles._();

  // Heading styles
  static TextStyle get h1 => AdminTypography.lightTextTheme.displayLarge!;
  static TextStyle get h2 => AdminTypography.lightTextTheme.displayMedium!;
  static TextStyle get h3 => AdminTypography.lightTextTheme.displaySmall!;
  static TextStyle get h4 => AdminTypography.lightTextTheme.headlineLarge!;
  static TextStyle get h5 => AdminTypography.lightTextTheme.headlineMedium!;
  static TextStyle get h6 => AdminTypography.lightTextTheme.headlineSmall!;

  // Body styles
  static TextStyle get bodyLarge => AdminTypography.lightTextTheme.bodyLarge!;
  static TextStyle get bodyMedium => AdminTypography.lightTextTheme.bodyMedium!;
  static TextStyle get bodySmall => AdminTypography.lightTextTheme.bodySmall!;

  // Button style
  static TextStyle get button => AdminTypography.lightTextTheme.labelLarge!;

  // Caption style
  static TextStyle get caption => AdminTypography.lightTextTheme.labelSmall!;
}
