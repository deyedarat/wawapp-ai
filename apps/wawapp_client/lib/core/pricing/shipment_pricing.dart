import '../models/shipment_type.dart';

/// Pricing multipliers for different shipment types
/// These multipliers are applied to the base price to account for:
/// - Special handling requirements
/// - Risk factors
/// - Loading/unloading time
/// - Driver expertise needed
class ShipmentPricingMultipliers {
  /// Food & Perishables: 1.10x
  /// Slightly higher due to time-sensitive delivery requirements
  static const double foodAndPerishables = 1.10;

  /// Furniture & Home Setup: 1.30x
  /// Higher due to larger items, careful handling, and loading time
  static const double furnitureAndHomeSetup = 1.30;

  /// Construction Materials & Heavy Load: 1.60x
  /// Highest multiplier due to:
  /// - Heavy weight requiring strong vehicle
  /// - Physical effort in loading/unloading
  /// - Potential vehicle wear and tear
  static const double constructionMaterialsAndHeavyLoad = 1.60;

  /// Electrical & Home Appliances: 1.25x
  /// Moderate increase for:
  /// - Careful handling required
  /// - Valuable items
  /// - Risk of damage
  static const double electricalAndHomeAppliances = 1.25;

  /// General Goods & Boxes: 1.00x (baseline)
  /// Standard rate - no adjustment
  static const double generalGoodsAndBoxes = 1.00;

  /// Fragile/Sensitive Cargo: 1.40x
  /// Higher rate for:
  /// - Extra careful handling
  /// - Slower driving required
  /// - Higher risk of damage
  /// - Potential insurance considerations
  static const double fragileOrSensitiveCargo = 1.40;

  /// Get the multiplier for a specific shipment type
  static double getMultiplier(ShipmentType type) {
    switch (type) {
      case ShipmentType.foodAndPerishables:
        return foodAndPerishables;
      case ShipmentType.furnitureAndHomeSetup:
        return furnitureAndHomeSetup;
      case ShipmentType.constructionMaterialsAndHeavyLoad:
        return constructionMaterialsAndHeavyLoad;
      case ShipmentType.electricalAndHomeAppliances:
        return electricalAndHomeAppliances;
      case ShipmentType.generalGoodsAndBoxes:
        return generalGoodsAndBoxes;
      case ShipmentType.fragileOrSensitiveCargo:
        return fragileOrSensitiveCargo;
    }
  }

  /// Get a human-readable description of the multiplier
  static String getMultiplierDescription(ShipmentType type) {
    final multiplier = getMultiplier(type);
    if (multiplier == 1.0) {
      return 'سعر عادي';
    } else if (multiplier > 1.0) {
      final percentage = ((multiplier - 1.0) * 100).round();
      return '+$percentage%';
    } else {
      final percentage = ((1.0 - multiplier) * 100).round();
      return '-$percentage%';
    }
  }
}

/// Helper method to apply shipment type multiplier to base price
/// 
/// This should be called after calculating the base price from distance/time
/// but before rounding to the nearest 5.
/// 
/// Example usage:
/// ```dart
/// final baseBreakdown = Pricing.compute(km);
/// final adjustedPrice = applyShipmentTypeMultiplier(
///   baseBreakdown.total.toDouble(),
///   selectedShipmentType,
/// );
/// final finalPrice = Pricing.roundTo5(adjustedPrice);
/// ```
double applyShipmentTypeMultiplier(
  double basePrice,
  ShipmentType? type,
) {
  // Use generalGoodsAndBoxes as fallback if type is null
  final shipmentType = type ?? ShipmentTypeExtension.defaultType;
  final multiplier = ShipmentPricingMultipliers.getMultiplier(shipmentType);
  return basePrice * multiplier;
}
