import 'package:flutter/material.dart';

/// Admin App Color Palette
/// Based on Manus Visual Identity (Mauritania flag colors)
class AdminAppColors {
  AdminAppColors._();

  // ========== Primary Colors (Manus Visual Identity) ==========
  static const Color primaryGreen = Color(0xFF00704A); // Mauritania Green
  static const Color goldenYellow = Color(0xFFF5A623); // Golden Yellow
  static const Color accentRed = Color(0xFFC1272D); // Mauritania Red accent

  // ========== Background Colors ==========
  static const Color backgroundLight = Color(0xFFF8F9FA); // Light mode background
  static const Color backgroundDark = Color(0xFF0A1612); // Dark mode background
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2C2C2C);

  // ========== Text Colors ==========
  static const Color textPrimaryLight = Color(0xFF212529); // Manus spec
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textDisabledLight = Color(0xFFD1D5DB);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
  static const Color textDisabledDark = Color(0xFF6B7280);

  // ========== Semantic Colors ==========
  static const Color successLight = Color(0xFF10B981);
  static const Color successDark = Color(0xFF34D399);
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color errorLight = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFF87171);
  static const Color infoLight = Color(0xFF3B82F6);
  static const Color infoDark = Color(0xFF60A5FA);

  // ========== Status Colors ==========
  static const Color onlineGreen = Color(0xFF00704A);
  static const Color offlineGrey = Color(0xFF9E9E9E);
  static const Color activeBlue = Color(0xFF2196F3);
  static const Color pendingYellow = Color(0xFFFFA000);

  // ========== Border & Divider ==========
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF374151);
  static const Color dividerLight = Color(0xFFE5E7EB);
  static const Color dividerDark = Color(0xFF374151);

  // ========== Overlay & Shadow ==========
  static const Color overlayLight = Color(0x0F000000);
  static const Color overlayDark = Color(0x1FFFFFFF);
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x3D000000);
}

/// Spacing constants for consistent padding/margins
class AdminSpacing {
  AdminSpacing._();

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
  static const double sidebarWidth = 280.0;
  static const double sidebarWidthCollapsed = 72.0;
  static const double appBarHeight = 64.0;
  static const double cardPadding = md;
  static const double screenPadding = lg;

  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;
}

/// Elevation constants
class AdminElevation {
  AdminElevation._();

  static const double none = 0;
  static const double low = 2;
  static const double medium = 4;
  static const double high = 8;
  static const double veryHigh = 16;
}
