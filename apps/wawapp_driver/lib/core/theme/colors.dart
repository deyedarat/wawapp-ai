import 'package:flutter/material.dart';

/// Driver App Color Palette
/// Professional colors for the logistics and transportation industry
class DriverAppColors {
  DriverAppColors._();

  // ========== Primary Colors ==========
  static const Color primaryLight = Color(0xFF2E7D32); // Dark Green
  static const Color primaryDark = Color(0xFF66BB6A); // Light Green
  
  static const Color secondaryLight = Color(0xFFFF6F00); // Deep Orange
  static const Color secondaryDark = Color(0xFFFFB74D); // Light Orange

  // ========== Status Colors ==========
  static const Color onlineGreen = Color(0xFF4CAF50);
  static const Color offlineGrey = Color(0xFF9E9E9E);
  static const Color busyOrange = Color(0xFFFF9800);
  static const Color acceptedBlue = Color(0xFF2196F3);
  
  // ========== Semantic Colors (Light) ==========
  static const Color successLight = Color(0xFF10B981);
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color errorLight = Color(0xFFEF4444);
  static const Color infoLight = Color(0xFF3B82F6);
  
  // ========== Semantic Colors (Dark) ==========
  static const Color successDark = Color(0xFF34D399);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color errorDark = Color(0xFFF87171);
  static const Color infoDark = Color(0xFF60A5FA);

  // ========== Background Colors (Light) ==========
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  // ========== Background Colors (Dark) ==========
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2C2C2C);

  // ========== Text Colors (Light) ==========
  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textDisabledLight = Color(0xFFD1D5DB);

  // ========== Text Colors (Dark) ==========
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
  static const Color textDisabledDark = Color(0xFF6B7280);

  // ========== Border Colors ==========
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF374151);

  // ========== Divider Colors ==========
  static const Color dividerLight = Color(0xFFE5E7EB);
  static const Color dividerDark = Color(0xFF374151);

  // ========== Overlay Colors ==========
  static const Color overlayLight = Color(0x0F000000);
  static const Color overlayDark = Color(0x1FFFFFFF);

  // ========== Shadow Colors ==========
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x3D000000);

  // ========== Order Status Colors ==========
  static const Color pendingYellow = Color(0xFFFFA000);
  static const Color enRouteBlue = Color(0xFF0288D1);
  static const Color completedGreen = Color(0xFF388E3C);
  static const Color cancelledRed = Color(0xFFD32F2F);
}

/// Spacing constants for consistent padding/margins
class DriverAppSpacing {
  DriverAppSpacing._();

  static const double baseUnit = 8.0;

  static const double xxs = baseUnit * 0.5; // 4
  static const double xs = baseUnit; // 8
  static const double sm = baseUnit * 1.5; // 12
  static const double md = baseUnit * 2; // 16
  static const double lg = baseUnit * 3; // 24
  static const double xl = baseUnit * 4; // 32
  static const double xxl = baseUnit * 5; // 40
  static const double xxxl = baseUnit * 6; // 48

  // Component-specific spacing
  static const double cardPadding = md;
  static const double screenPadding = md;
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
  static const double appBarHeight = 56.0;

  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;
}

/// Elevation constants for consistent shadows
class DriverAppElevation {
  DriverAppElevation._();

  static const double none = 0;
  static const double low = 2;
  static const double medium = 4;
  static const double high = 8;
  static const double veryHigh = 16;
}
