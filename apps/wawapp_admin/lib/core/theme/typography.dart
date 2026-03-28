import 'package:flutter/material.dart';
import 'colors.dart';

/// Admin App Typography
/// Based on Manus Visual Identity (Inter & DM Sans fonts)
class AdminTypography {
  AdminTypography._();

  // Font families (Manus spec: Inter for headings/UI, DM Sans for body)
  static const String primaryFont = 'Inter';
  static const String secondaryFont = 'DM Sans';

  /// Light theme text styles
  static TextTheme lightTextTheme = TextTheme(
    // Display styles (large headings)
    displayLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 57,
      fontWeight: FontWeight.bold,
      color: AdminAppColors.textPrimaryLight,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 45,
      fontWeight: FontWeight.bold,
      color: AdminAppColors.textPrimaryLight,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: AdminAppColors.textPrimaryLight,
      height: 1.2,
    ),

    // Headline styles
    headlineLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: AdminAppColors.textPrimaryLight,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.3,
    ),

    // Title styles
    titleLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AdminAppColors.textPrimaryLight,
      height: 1.4,
    ),

    // Body styles
    bodyLarge: TextStyle(
      fontFamily: secondaryFont,
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: AdminAppColors.textPrimaryLight,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: secondaryFont,
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: AdminAppColors.textPrimaryLight,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: secondaryFont,
      fontSize: 12,
      fontWeight: FontWeight.normal,
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
