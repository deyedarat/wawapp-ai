/// Theme extensions for WawApp Client
/// Custom theme data that extends Flutter's ThemeData
library;

import 'package:flutter/material.dart';
import 'colors.dart';

/// Shipment Type Colors Extension
/// Provides colors for each shipment type category
class ShipmentTypeColors extends ThemeExtension<ShipmentTypeColors> {
  final Color foodPerishables;
  final Color furniture;
  final Color construction;
  final Color appliances;
  final Color generalGoods;
  final Color fragile;

  const ShipmentTypeColors({
    required this.foodPerishables,
    required this.furniture,
    required this.construction,
    required this.appliances,
    required this.generalGoods,
    required this.fragile,
  });

  /// Light theme shipment colors
  factory ShipmentTypeColors.light() {
    return const ShipmentTypeColors(
      foodPerishables: WawAppColors.shipmentFood,
      furniture: WawAppColors.shipmentFurniture,
      construction: WawAppColors.shipmentConstruction,
      appliances: WawAppColors.shipmentAppliances,
      generalGoods: WawAppColors.shipmentGeneral,
      fragile: WawAppColors.shipmentFragile,
    );
  }

  /// Dark theme shipment colors (slightly adjusted for dark backgrounds)
  factory ShipmentTypeColors.dark() {
    return const ShipmentTypeColors(
      foodPerishables: WawAppColors.shipmentFood,
      furniture: WawAppColors.shipmentFurniture,
      construction: WawAppColors.shipmentConstruction,
      appliances: WawAppColors.shipmentAppliances,
      generalGoods: WawAppColors.shipmentGeneral,
      fragile: WawAppColors.shipmentFragile,
    );
  }

  @override
  ThemeExtension<ShipmentTypeColors> copyWith({
    Color? foodPerishables,
    Color? furniture,
    Color? construction,
    Color? appliances,
    Color? generalGoods,
    Color? fragile,
  }) {
    return ShipmentTypeColors(
      foodPerishables: foodPerishables ?? this.foodPerishables,
      furniture: furniture ?? this.furniture,
      construction: construction ?? this.construction,
      appliances: appliances ?? this.appliances,
      generalGoods: generalGoods ?? this.generalGoods,
      fragile: fragile ?? this.fragile,
    );
  }

  @override
  ThemeExtension<ShipmentTypeColors> lerp(
    covariant ThemeExtension<ShipmentTypeColors>? other,
    double t,
  ) {
    if (other is! ShipmentTypeColors) return this;
    
    return ShipmentTypeColors(
      foodPerishables: Color.lerp(foodPerishables, other.foodPerishables, t)!,
      furniture: Color.lerp(furniture, other.furniture, t)!,
      construction: Color.lerp(construction, other.construction, t)!,
      appliances: Color.lerp(appliances, other.appliances, t)!,
      generalGoods: Color.lerp(generalGoods, other.generalGoods, t)!,
      fragile: Color.lerp(fragile, other.fragile, t)!,
    );
  }
}

/// Additional custom theme data
class WawAppThemeData extends ThemeExtension<WawAppThemeData> {
  final Color successColor;
  final Color warningColor;
  final Color infoColor;
  
  final Color inputFillColor;
  final Color inputBorderColor;
  
  final Color dividerColor;
  final Color overlayColor;
  
  const WawAppThemeData({
    required this.successColor,
    required this.warningColor,
    required this.infoColor,
    required this.inputFillColor,
    required this.inputBorderColor,
    required this.dividerColor,
    required this.overlayColor,
  });

  /// Light theme custom data
  factory WawAppThemeData.light() {
    return const WawAppThemeData(
      successColor: WawAppColors.success,
      warningColor: WawAppColors.warning,
      infoColor: WawAppColors.info,
      inputFillColor: WawAppColors.inputFillLight,
      inputBorderColor: WawAppColors.inputBorderLight,
      dividerColor: WawAppColors.dividerLight,
      overlayColor: WawAppColors.overlayLight,
    );
  }

  /// Dark theme custom data
  factory WawAppThemeData.dark() {
    return const WawAppThemeData(
      successColor: WawAppColors.success,
      warningColor: WawAppColors.warning,
      infoColor: WawAppColors.info,
      inputFillColor: WawAppColors.inputFillDark,
      inputBorderColor: WawAppColors.inputBorderDark,
      dividerColor: WawAppColors.dividerDark,
      overlayColor: WawAppColors.overlayDark,
    );
  }

  @override
  ThemeExtension<WawAppThemeData> copyWith({
    Color? successColor,
    Color? warningColor,
    Color? infoColor,
    Color? inputFillColor,
    Color? inputBorderColor,
    Color? dividerColor,
    Color? overlayColor,
  }) {
    return WawAppThemeData(
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      infoColor: infoColor ?? this.infoColor,
      inputFillColor: inputFillColor ?? this.inputFillColor,
      inputBorderColor: inputBorderColor ?? this.inputBorderColor,
      dividerColor: dividerColor ?? this.dividerColor,
      overlayColor: overlayColor ?? this.overlayColor,
    );
  }

  @override
  ThemeExtension<WawAppThemeData> lerp(
    covariant ThemeExtension<WawAppThemeData>? other,
    double t,
  ) {
    if (other is! WawAppThemeData) return this;
    
    return WawAppThemeData(
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
      inputFillColor: Color.lerp(inputFillColor, other.inputFillColor, t)!,
      inputBorderColor: Color.lerp(inputBorderColor, other.inputBorderColor, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      overlayColor: Color.lerp(overlayColor, other.overlayColor, t)!,
    );
  }
}

/// Extension to access custom theme data from BuildContext
extension ThemeExtensionGetters on BuildContext {
  /// Get shipment type colors
  ShipmentTypeColors get shipmentTypeColors {
    return Theme.of(this).extension<ShipmentTypeColors>() ??
        ShipmentTypeColors.light();
  }

  /// Get WawApp custom theme data
  WawAppThemeData get wawAppTheme {
    return Theme.of(this).extension<WawAppThemeData>() ??
        WawAppThemeData.light();
  }
  
  /// Quick access to common custom colors
  Color get successColor => wawAppTheme.successColor;
  Color get warningColor => wawAppTheme.warningColor;
  Color get errorColor => Theme.of(this).colorScheme.error;
  Color get infoColor => wawAppTheme.infoColor;
}
