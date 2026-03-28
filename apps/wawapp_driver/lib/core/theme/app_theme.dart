import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: DriverAppColors.primaryLight,
        secondary: DriverAppColors.secondaryLight,
        surface: DriverAppColors.surfaceLight,
        error: DriverAppColors.errorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: DriverAppColors.textPrimaryLight,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: DriverAppColors.backgroundLight,
      cardColor: DriverAppColors.cardLight,
      dividerColor: DriverAppColors.dividerLight,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.25),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ).apply(
        bodyColor: DriverAppColors.textPrimaryLight,
        displayColor: DriverAppColors.textPrimaryLight,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: DriverAppElevation.low,
        backgroundColor: DriverAppColors.primaryLight,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: DriverAppElevation.low,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
        ),
        color: DriverAppColors.cardLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DriverAppColors.primaryLight,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: DriverAppSpacing.lg,
            vertical: DriverAppSpacing.sm,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          ),
          elevation: DriverAppElevation.low,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DriverAppColors.primaryLight,
          padding: EdgeInsets.symmetric(
            horizontal: DriverAppSpacing.lg,
            vertical: DriverAppSpacing.sm,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          ),
          side: const BorderSide(color: DriverAppColors.primaryLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DriverAppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          borderSide: const BorderSide(color: DriverAppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          borderSide: const BorderSide(color: DriverAppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          borderSide:
              const BorderSide(color: DriverAppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          borderSide: const BorderSide(color: DriverAppColors.errorLight),
        ),
        contentPadding: EdgeInsets.all(DriverAppSpacing.md),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: DriverAppColors.primaryDark,
        secondary: DriverAppColors.secondaryDark,
        surface: DriverAppColors.surfaceDark,
        error: DriverAppColors.errorDark,
        onPrimary: DriverAppColors.backgroundDark,
        onSecondary: DriverAppColors.backgroundDark,
        onSurface: DriverAppColors.textPrimaryDark,
        onError: DriverAppColors.backgroundDark,
      ),
      scaffoldBackgroundColor: DriverAppColors.backgroundDark,
      cardColor: DriverAppColors.cardDark,
      dividerColor: DriverAppColors.dividerDark,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.25),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ).apply(
        bodyColor: DriverAppColors.textPrimaryDark,
        displayColor: DriverAppColors.textPrimaryDark,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: DriverAppElevation.low,
        backgroundColor: DriverAppColors.surfaceDark,
        foregroundColor: DriverAppColors.textPrimaryDark,
        iconTheme: IconThemeData(color: DriverAppColors.textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        elevation: DriverAppElevation.low,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
        ),
        color: DriverAppColors.cardDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DriverAppColors.primaryDark,
          foregroundColor: DriverAppColors.backgroundDark,
          padding: EdgeInsets.symmetric(
            horizontal: DriverAppSpacing.lg,
            vertical: DriverAppSpacing.sm,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          ),
          elevation: DriverAppElevation.low,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DriverAppColors.primaryDark,
          padding: EdgeInsets.symmetric(
            horizontal: DriverAppSpacing.lg,
            vertical: DriverAppSpacing.sm,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          ),
          side: BorderSide(color: DriverAppColors.primaryDark),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DriverAppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          borderSide: const BorderSide(color: DriverAppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          borderSide: const BorderSide(color: DriverAppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          borderSide:
              const BorderSide(color: DriverAppColors.primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          borderSide: const BorderSide(color: DriverAppColors.errorDark),
        ),
        contentPadding: EdgeInsets.all(DriverAppSpacing.md),
      ),
    );
  }
}
