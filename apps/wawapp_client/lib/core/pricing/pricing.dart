import '../models/shipment_type.dart';
import '../models/cargo_weight.dart';
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
  int weightCost,
  double weightTons,
});

class PricingConfig {
  static const int base = 60;
  static const int perKm = 20;
  static const int minFare = 100;
  static const double antigravityMultiplier = 2.2;
  static const int perTonMRU = 140;
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

  /// Compute price WITH shipment type multiplier + antigravity factor + cargo weight
  ///
  /// Formula:
  ///   subtotal = (base + distancePart) × shipmentMultiplier × 2.2
  ///   subtotal = max(subtotal, minFare)
  ///   rounded  = roundTo5(subtotal)
  ///   finalPrice = rounded + weightCost
  static PricingBreakdown computeWithShipmentType(
    double km,
    ShipmentType? shipmentType, {
    CargoWeight? cargoWeight,
  }) {
    // Base distance calculation
    const base = PricingConfig.base;
    final distancePart = (PricingConfig.perKm * km).round();
    final rawTotal = base + distancePart;

    // Apply shipment type multiplier
    final multiplier = ShipmentPricingMultipliers.getMultiplier(
      shipmentType ?? ShipmentTypeExtension.defaultType,
    );
    final afterShipment = rawTotal * multiplier;

    // Apply antigravity factor ×2.2
    final afterAntigravity =
        afterShipment * PricingConfig.antigravityMultiplier;

    // Apply minimum fare
    final withMin = afterAntigravity < PricingConfig.minFare
        ? PricingConfig.minFare.toDouble()
        : afterAntigravity;

    // Round to nearest 5 (before adding weight cost)
    final rounded = roundTo5(withMin);

    // Weight cost added AFTER rounding
    final selectedWeight = cargoWeight ?? CargoWeightExtension.defaultWeight;
    final weightCost = selectedWeight.costMRU;

    return (
      total: rawTotal,
      base: base,
      distancePart: distancePart,
      rounded: rounded,
      km: km,
      multiplier: multiplier,
      adjustedTotal: afterAntigravity.round(),
      weightCost: weightCost,
      weightTons: selectedWeight.tons,
    );
  }
}
