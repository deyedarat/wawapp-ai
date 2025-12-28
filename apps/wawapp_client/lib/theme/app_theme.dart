/// WawApp Theme System
/// 
/// Provides complete theme configuration for light and dark modes.
/// Includes all component themes, typography, and custom extensions.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'typography.dart';
import 'theme_extensions.dart';

class WawAppTheme {
  WawAppTheme._(); // Private constructor

  // ============================================================================
  // LIGHT THEME
  // ============================================================================
  
  static ThemeData light() {
    const primary = WawAppColors.primary;
    const secondary = WawAppColors.secondary;
    const background = WawAppColors.backgroundLight;
    const surface = WawAppColors.surfaceLight;
    const error = WawAppColors.error;
    
    final colorScheme = ColorScheme.light(
      primary: primary,
      secondary: secondary,
      error: error,
      surface: surface,
      onPrimary: Colors.white,
      onSecondary: WawAppColors.textPrimaryLight,
      onSurface: WawAppColors.textPrimaryLight,
      onError: Colors.white,
      // Additional colors
      tertiary: WawAppColors.success,
      primaryContainer: WawAppColors.primaryLight,
      secondaryContainer: WawAppColors.secondaryLight,
      surfaceContainerHighest: WawAppColors.inputFillLight,
      outline: WawAppColors.borderLight,
      outlineVariant: WawAppColors.dividerLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      
      // Typography
      textTheme: WawAppTypography.lightTextTheme,
      primaryTextTheme: WawAppTypography.lightTextTheme,
      
      // AppBar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: WawAppTypography.lightTextTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 24),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: WawAppElevation.medium,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: WawAppColors.primaryDisabled,
          disabledForegroundColor: Colors.white.withOpacity(0.5),
          elevation: WawAppElevation.medium,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: WawAppSpacing.lg,
            vertical: WawAppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          ),
          minimumSize: Size(0, WawAppSpacing.buttonHeight),
          textStyle: WawAppTypography.lightTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: WawAppSpacing.md,
            vertical: WawAppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
          ),
          textStyle: WawAppTypography.lightTextTheme.labelLarge,
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: WawAppSpacing.lg,
            vertical: WawAppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          ),
          minimumSize: Size(0, WawAppSpacing.buttonHeight),
          textStyle: WawAppTypography.lightTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WawAppColors.inputFillLight,
        contentPadding: EdgeInsetsDirectional.symmetric(
          horizontal: WawAppSpacing.md,
          vertical: WawAppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: WawAppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: WawAppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: BorderSide(
            color: WawAppColors.borderLight.withOpacity(0.5),
          ),
        ),
        labelStyle: WawAppTypography.lightTextTheme.bodyMedium?.copyWith(
          color: WawAppColors.textSecondaryLight,
        ),
        floatingLabelStyle: WawAppTypography.lightTextTheme.bodyMedium?.copyWith(
          color: primary,
        ),
        hintStyle: WawAppTypography.lightTextTheme.bodySmall?.copyWith(
          color: WawAppColors.textSecondaryLight,
        ),
        errorStyle: WawAppTypography.lightTextTheme.bodySmall?.copyWith(
          color: error,
        ),
        prefixIconColor: WawAppColors.textSecondaryLight,
        suffixIconColor: WawAppColors.textSecondaryLight,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: WawAppColors.textPrimaryLight,
        size: 24,
      ),
      primaryIconTheme: const IconThemeData(
        color: primary,
        size: 24,
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: WawAppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: WawAppColors.inputFillLight,
        deleteIconColor: WawAppColors.textSecondaryLight,
        disabledColor: WawAppColors.inputFillLight.withOpacity(0.5),
        selectedColor: primary.withOpacity(0.1),
        secondarySelectedColor: secondary.withOpacity(0.1),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: WawAppSpacing.sm,
          vertical: WawAppSpacing.xs,
        ),
        labelStyle: WawAppTypography.lightTextTheme.labelSmall,
        secondaryLabelStyle: WawAppTypography.lightTextTheme.labelSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusLg),
        ),
      ),
      
      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: WawAppElevation.veryHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusLg),
        ),
        titleTextStyle: WawAppTypography.lightTextTheme.titleLarge,
        contentTextStyle: WawAppTypography.lightTextTheme.bodyMedium,
      ),
      
      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: WawAppElevation.veryHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WawAppSpacing.radiusXl),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WawAppColors.textPrimaryLight,
        contentTextStyle: WawAppTypography.lightTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: WawAppElevation.high,
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: WawAppColors.dividerLight,
        circularTrackColor: WawAppColors.dividerLight,
      ),
      
      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return WawAppColors.textSecondaryLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withOpacity(0.5);
          }
          return WawAppColors.dividerLight;
        }),
      ),
      
      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: WawAppColors.borderLight, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusXs),
        ),
      ),
      
      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return WawAppColors.textSecondaryLight;
        }),
      ),
      
      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: WawAppColors.dividerLight,
        thumbColor: primary,
        overlayColor: primary.withOpacity(0.2),
        valueIndicatorColor: primary,
        valueIndicatorTextStyle: WawAppTypography.lightTextTheme.labelSmall?.copyWith(
          color: Colors.white,
        ),
      ),
      
      // FloatingActionButton Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: WawAppElevation.high,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusLg),
        ),
      ),
      
      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: WawAppElevation.veryHigh,
        indicatorColor: primary.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.all(
          WawAppTypography.lightTextTheme.labelSmall,
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(
            color: WawAppColors.textSecondaryLight,
            size: 24,
          );
        }),
      ),
      
      // Extensions
      extensions: <ThemeExtension<dynamic>>[
        ShipmentTypeColors.light(),
        WawAppThemeData.light(),
      ],
    );
  }

  // ============================================================================
  // DARK THEME
  // ============================================================================
  
  static ThemeData dark() {
    const primary = WawAppColors.primary;
    const secondary = WawAppColors.secondary;
    const background = WawAppColors.backgroundDark;
    const surface = WawAppColors.surfaceDark;
    const error = WawAppColors.error;
    
    final colorScheme = ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      error: error,
      surface: surface,
      onPrimary: Colors.white,
      onSecondary: WawAppColors.textPrimaryDark,
      onSurface: WawAppColors.textPrimaryDark,
      onError: Colors.white,
      // Additional colors
      tertiary: WawAppColors.success,
      primaryContainer: WawAppColors.primaryDark,
      secondaryContainer: WawAppColors.secondaryDark,
      surfaceContainerHighest: WawAppColors.inputFillDark,
      outline: WawAppColors.borderDark,
      outlineVariant: WawAppColors.dividerDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      
      // Typography
      textTheme: WawAppTypography.darkTextTheme,
      primaryTextTheme: WawAppTypography.darkTextTheme,
      
      // AppBar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: surface,
        foregroundColor: WawAppColors.textPrimaryDark,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: WawAppTypography.darkTextTheme.titleMedium?.copyWith(
          color: WawAppColors.textPrimaryDark,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(
          color: WawAppColors.textPrimaryDark,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: WawAppColors.textPrimaryDark,
          size: 24,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: WawAppElevation.medium,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: WawAppColors.primaryDisabled,
          disabledForegroundColor: Colors.white.withOpacity(0.5),
          elevation: WawAppElevation.medium,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: WawAppSpacing.lg,
            vertical: WawAppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          ),
          minimumSize: Size(0, WawAppSpacing.buttonHeight),
          textStyle: WawAppTypography.darkTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: WawAppSpacing.md,
            vertical: WawAppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
          ),
          textStyle: WawAppTypography.darkTextTheme.labelLarge,
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: WawAppSpacing.lg,
            vertical: WawAppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          ),
          minimumSize: Size(0, WawAppSpacing.buttonHeight),
          textStyle: WawAppTypography.darkTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WawAppColors.inputFillDark,
        contentPadding: EdgeInsetsDirectional.symmetric(
          horizontal: WawAppSpacing.md,
          vertical: WawAppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: WawAppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: WawAppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
          borderSide: BorderSide(
            color: WawAppColors.borderDark.withOpacity(0.5),
          ),
        ),
        labelStyle: WawAppTypography.darkTextTheme.bodyMedium?.copyWith(
          color: WawAppColors.textSecondaryDark,
        ),
        floatingLabelStyle: WawAppTypography.darkTextTheme.bodyMedium?.copyWith(
          color: primary,
        ),
        hintStyle: WawAppTypography.darkTextTheme.bodySmall?.copyWith(
          color: WawAppColors.textSecondaryDark,
        ),
        errorStyle: WawAppTypography.darkTextTheme.bodySmall?.copyWith(
          color: error,
        ),
        prefixIconColor: WawAppColors.textSecondaryDark,
        suffixIconColor: WawAppColors.textSecondaryDark,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: WawAppColors.textPrimaryDark,
        size: 24,
      ),
      primaryIconTheme: const IconThemeData(
        color: primary,
        size: 24,
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: WawAppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: WawAppColors.inputFillDark,
        deleteIconColor: WawAppColors.textSecondaryDark,
        disabledColor: WawAppColors.inputFillDark.withOpacity(0.5),
        selectedColor: primary.withOpacity(0.2),
        secondarySelectedColor: secondary.withOpacity(0.2),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: WawAppSpacing.sm,
          vertical: WawAppSpacing.xs,
        ),
        labelStyle: WawAppTypography.darkTextTheme.labelSmall,
        secondaryLabelStyle: WawAppTypography.darkTextTheme.labelSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusLg),
        ),
      ),
      
      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: WawAppElevation.veryHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusLg),
        ),
        titleTextStyle: WawAppTypography.darkTextTheme.titleLarge,
        contentTextStyle: WawAppTypography.darkTextTheme.bodyMedium,
      ),
      
      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: WawAppElevation.veryHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WawAppSpacing.radiusXl),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WawAppColors.cardDark,
        contentTextStyle: WawAppTypography.darkTextTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: WawAppElevation.high,
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: WawAppColors.dividerDark,
        circularTrackColor: WawAppColors.dividerDark,
      ),
      
      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return WawAppColors.textSecondaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withOpacity(0.5);
          }
          return WawAppColors.dividerDark;
        }),
      ),
      
      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: WawAppColors.borderDark, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusXs),
        ),
      ),
      
      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return WawAppColors.textSecondaryDark;
        }),
      ),
      
      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: WawAppColors.dividerDark,
        thumbColor: primary,
        overlayColor: primary.withOpacity(0.2),
        valueIndicatorColor: primary,
        valueIndicatorTextStyle: WawAppTypography.darkTextTheme.labelSmall?.copyWith(
          color: Colors.white,
        ),
      ),
      
      // FloatingActionButton Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: WawAppElevation.high,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WawAppSpacing.radiusLg),
        ),
      ),
      
      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: WawAppElevation.veryHigh,
        indicatorColor: primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          WawAppTypography.darkTextTheme.labelSmall,
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(
            color: WawAppColors.textSecondaryDark,
            size: 24,
          );
        }),
      ),
      
      // Extensions
      extensions: <ThemeExtension<dynamic>>[
        ShipmentTypeColors.dark(),
        WawAppThemeData.dark(),
      ],
    );
  }
}
