import 'package:flutter/material.dart';

/// Responsive helper class for adaptive layouts
class ResponsiveHelper {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Get responsive table height based on screen size
  static double getTableHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Use 60% of screen height minus app bar and padding
    return (screenHeight * 0.6).clamp(400.0, 800.0);
  }

  /// Get responsive card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(12);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  /// Get responsive column count for grid layouts
  static int getGridColumnCount(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 4;
    }
  }

  /// Get responsive value based on screen size
  static T responsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return desktop;
  }

  /// Get responsive padding
  static EdgeInsets responsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(12);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  /// Get responsive font size
  static double responsiveFontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    required double desktop,
  }) {
    return responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// Get responsive width (useful for search bars, dialogs, etc.)
  static double responsiveWidth(
    BuildContext context, {
    required double mobile,
    double? tablet,
    required double desktop,
  }) {
    return responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// Check if should show mobile layout (hamburger menu, etc.)
  static bool shouldShowMobileLayout(BuildContext context) {
    return isMobile(context);
  }

  /// Get responsive app bar height
  static double getAppBarHeight(BuildContext context) {
    return isMobile(context) ? 56.0 : 64.0;
  }

  /// Get responsive sidebar width
  static double getSidebarWidth(BuildContext context, {bool isCollapsed = false}) {
    if (isCollapsed) return 72.0;
    return isMobile(context) ? 280.0 : 280.0;
  }
}
