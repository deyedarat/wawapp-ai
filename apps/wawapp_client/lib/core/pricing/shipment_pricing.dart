import 'package:core_shared/core_shared.dart';

/// Pricing multipliers for different shipment types.
/// Now delegates to core_shared ShipmentTypeExtension.multiplier.
class ShipmentPricingMultipliers {
  /// Get the multiplier for a specific shipment type
  static double getMultiplier(ShipmentType type) => type.multiplier;

  /// Get a human-readable description of the multiplier
  static String getMultiplierDescription(ShipmentType type) {
    final multiplier = type.multiplier;
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
