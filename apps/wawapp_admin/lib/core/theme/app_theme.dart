import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

/// Admin App Theme Configuration
class AdminAppTheme {
  AdminAppTheme._();

  /// Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color scheme
      colorScheme: ColorScheme.light(
        primary: AdminAppColors.primaryGreen,
        secondary: AdminAppColors.goldenYellow,
        error: AdminAppColors.errorLight,
        surface: AdminAppColors.surfaceLight,
        surfaceContainerHighest: AdminAppColors.backgroundLight,
      ),

      // Scaffold
      scaffoldBackgroundColor: AdminAppColors.backgroundLight,

      // App bar
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AdminAppColors.surfaceLight,
        foregroundColor: AdminAppColors.textPrimaryLight,
        centerTitle: false,
        titleTextStyle: AdminTypography.lightTextTheme.titleLarge,
      ),

      // Card
      cardTheme: CardTheme(
        elevation: AdminElevation.low,
        color: AdminAppColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
        ),
      ),

      // Text theme
      textTheme: AdminTypography.lightTextTheme,

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminAppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: AdminElevation.low,
          padding: EdgeInsets.symmetric(
            horizontal: AdminSpacing.lg,
            vertical: AdminSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: AdminTypography.primaryFont,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminAppColors.primaryGreen,
          side: const BorderSide(color: AdminAppColors.primaryGreen),
          padding: EdgeInsets.symmetric(
            horizontal: AdminSpacing.lg,
            vertical: AdminSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: AdminTypography.primaryFont,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminAppColors.primaryGreen,
          padding: EdgeInsets.symmetric(
            horizontal: AdminSpacing.md,
            vertical: AdminSpacing.sm,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: AdminTypography.primaryFont,
          ),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminAppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          borderSide: const BorderSide(color: AdminAppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          borderSide: const BorderSide(color: AdminAppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          borderSide: const BorderSide(color: AdminAppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          borderSide: const BorderSide(color: AdminAppColors.errorLight),
        ),
        contentPadding: EdgeInsets.all(AdminSpacing.md),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AdminAppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),

      // Drawer
      drawerTheme: DrawerThemeData(
        backgroundColor: AdminAppColors.surfaceLight,
        elevation: AdminElevation.medium,
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: AdminAppColors.primaryGreen,
        secondary: AdminAppColors.goldenYellow,
        error: AdminAppColors.errorDark,
        surface: AdminAppColors.surfaceDark,
        surfaceContainerHighest: AdminAppColors.backgroundDark,
      ),

      // Scaffold
      scaffoldBackgroundColor: AdminAppColors.backgroundDark,

      // App bar
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AdminAppColors.surfaceDark,
        foregroundColor: AdminAppColors.textPrimaryDark,
        centerTitle: false,
        titleTextStyle: AdminTypography.darkTextTheme.titleLarge,
      ),

      // Card
      cardTheme: CardTheme(
        elevation: AdminElevation.low,
        color: AdminAppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
        ),
      ),

      // Text theme
      textTheme: AdminTypography.darkTextTheme,

      // Button themes (similar to light but with dark colors)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminAppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: AdminElevation.low,
          padding: EdgeInsets.symmetric(
            horizontal: AdminSpacing.lg,
            vertical: AdminSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          ),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminAppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          borderSide: const BorderSide(color: AdminAppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          borderSide: const BorderSide(color: AdminAppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          borderSide: const BorderSide(color: AdminAppColors.primaryGreen, width: 2),
        ),
        contentPadding: EdgeInsets.all(AdminSpacing.md),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AdminAppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),

      // Drawer
      drawerTheme: DrawerThemeData(
        backgroundColor: AdminAppColors.surfaceDark,
        elevation: AdminElevation.medium,
      ),
    );
  }
}
