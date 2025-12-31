/// Color definitions for WawApp Client
/// All colors used throughout the app are defined here.
/// No inline color values should be used in the UI code.
library;

import 'package:flutter/material.dart';

/// Light Theme Colors
class WawAppColors {
  WawAppColors._();

  // Primary Brand Colors (Manus Visual Identity - Mauritania Flag)
  static const Color primary = Color(0xFF00704A); // Mauritania Green
  static const Color primaryDark = Color(0xFF005539);
  static const Color primaryLight = Color(0xFF00A76F);

  static const Color secondary = Color(0xFFF5A623); // Golden Yellow
  static const Color secondaryDark = Color(0xFFE09419);
  static const Color secondaryLight = Color(0xFFFFC156);

  // Semantic Colors (Light Theme)
  static const Color success = Color(0xFF00704A); // Mauritania Green
  static const Color warning = Color(0xFFF5A623); // Golden Yellow
  static const Color error = Color(0xFFC1272D); // Accent Red
  static const Color info = Color(0xFF3498DB); // Light Blue

  // Background & Surface (Light)
  static const Color backgroundLight = Color(0xFFF8F9FA); // Manus design spec
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Text Colors (Light Theme)
  static const Color textPrimaryLight = Color(0xFF212529); // Manus design spec
  static const Color textSecondaryLight = Color(0xFF6C757D);
  static const Color textDisabledLight = Color(0xFFADB5BD);

  // Border & Divider (Light)
  static const Color borderLight = Color(0xFFDEE2E6);
  static const Color dividerLight = Color(0xFFE9ECEF);

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0A1612); // Manus design spec
  static const Color surfaceDark = Color(0xFF1D1D1D);
  static const Color cardDark = Color(0xFF2C2C2C);

  // Text Colors (Dark Theme)
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textDisabledDark = Color(0xFF6C6C6C);

  // Border & Divider (Dark)
  static const Color borderDark = Color(0xFF3A3A3A);
  static const Color dividerDark = Color(0xFF2A2A2A);

  // Input Field Colors
  static const Color inputFillLight = Color(0xFFF0F3F9);
  static const Color inputFillDark = Color(0xFF2A2A2A);
  static const Color inputBorderLight = Color(0xFFCED4DA);
  static const Color inputBorderDark = Color(0xFF4A4A4A);

  // Shipment Type Colors (as per requirements)
  static const Color shipmentFood = Color(0xFF2ECC71); // Green
  static const Color shipmentFurniture = Color(0xFFA0522D); // Brown
  static const Color shipmentConstruction = Color(0xFFE67E22); // Orange
  static const Color shipmentAppliances = Color(0xFF2980B9); // Blue
  static const Color shipmentGeneral = Color(0xFF7F8C8D); // Grey
  static const Color shipmentFragile = Color(0xFFC0392B); // Red

  // Overlay & Shadow
  static const Color overlayLight = Color(0x1F000000); // 12% black
  static const Color overlayDark = Color(0x33FFFFFF); // 20% white
  static const Color shadow = Color(0x1A000000); // 10% black

  // Disabled States
  static const Color disabledLight = Color(0xFFE9ECEF);
  static const Color disabledDark = Color(0xFF3A3A3A);

  // Button disabled colors with 25% opacity as per requirements
  static Color get primaryDisabled => primary.withOpacity(0.25);
  static Color get secondaryDisabled => secondary.withOpacity(0.25);
}

/// Spacing constants to avoid magic numbers
class WawAppSpacing {
  WawAppSpacing._();

  // Base spacing unit
  static const double base = 8.0;

  // Common spacing values
  static const double xxs = base * 0.5; // 4
  static const double xs = base; // 8
  static const double sm = base * 1.5; // 12
  static const double md = base * 2; // 16
  static const double lg = base * 3; // 24
  static const double xl = base * 4; // 32
  static const double xxl = base * 5; // 40
  static const double xxxl = base * 6; // 48

  // Specific component spacing
  static const double cardPadding = md; // 16
  static const double screenPadding = md; // 16
  static const double buttonHeight = 52.0;
  static const double inputHeight = 56.0;
  static const double appBarHeight = 56.0;

  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;
}

/// Elevation constants
class WawAppElevation {
  WawAppElevation._();

  static const double none = 0.0;
  static const double low = 1.0;
  static const double medium = 2.0;
  static const double high = 4.0;
  static const double veryHigh = 8.0;
}
