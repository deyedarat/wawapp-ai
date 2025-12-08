import '../models/shipment_type.dart';
import 'shipment_pricing.dart';

/// Type alias for pricing breakdown result
typedef PricingBreakdown = ({
  int total,
  int base,
  int distancePart,
  int rounded,
  double km,
  double multiplier,
  int adjustedTotal,
});

class PricingConfig {
  static const int base = 60;
  static const int perKm = 20;
  static const int minFare = 100;
}

class Pricing {
  static int roundTo5(num v) => (v / 5).round() * 5;

  /// Compute base price without shipment type adjustment
  static ({int total, int base, int distancePart, int rounded, double km})
      compute(double km) {
    const base = PricingConfig.base;
    final distancePart = (PricingConfig.perKm * km).round();
    final total = base + distancePart;
    final withMin =
        total < PricingConfig.minFare ? PricingConfig.minFare : total;
    final rounded = roundTo5(withMin);
    return (
      total: total,
      base: base,
      distancePart: distancePart,
      rounded: rounded,
      km: km
    );
  }

  /// Compute price WITH shipment type multiplier
  /// This is the recommended method to use for order pricing
  static ({
    int total,
    int base,
    int distancePart,
    int rounded,
    double km,
    double multiplier,
    int adjustedTotal,
  }) computeWithShipmentType(double km, ShipmentType? shipmentType) {
    // Get base calculation
    final baseCalc = compute(km);
    
    // Apply shipment type multiplier
    final adjustedPrice = applyShipmentTypeMultiplier(
      baseCalc.total.toDouble(),
      shipmentType,
    );
    
    // Apply minimum fare to adjusted price
    final withMin = adjustedPrice < PricingConfig.minFare 
        ? PricingConfig.minFare 
        : adjustedPrice;
    
    // Round to nearest 5
    final rounded = roundTo5(withMin);
    
    final multiplier = ShipmentPricingMultipliers.getMultiplier(
      shipmentType ?? ShipmentTypeExtension.defaultType,
    );
    
    return (
      total: baseCalc.total,
      base: baseCalc.base,
      distancePart: baseCalc.distancePart,
      rounded: rounded,
      km: km,
      multiplier: multiplier,
      adjustedTotal: adjustedPrice.round(),
    );
  }
}
