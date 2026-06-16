import 'shipment_type.dart';
import 'cargo_weight.dart';

/// Pricing breakdown result type.
/// [total] = rawTotal (base + distancePart) for backward compatibility.
/// Final display price = rounded + weightCost.
typedef PricingBreakdown = ({
  int total,
  int base,
  int distancePart,
  int rawTotal,
  int rounded,
  double km,
  double multiplier,
  int adjustedTotal,
  int weightCost,
  double weightTons,
});

/// Canonical pricing configuration for WawApp.
///
/// Supports both hardcoded defaults (fallback) and dynamic Firestore values.
/// Call [PricingConfig.loadFromMap] at app startup to override defaults
/// with values from Firestore `pricing_configs` collection.
class PricingConfig {
  // --- Default (fallback) values ---
  static const int _defaultBase = 60;
  static const int _defaultPerKm = 20;
  static const int _defaultMinFare = 100;
  static const double _defaultAntigravityMultiplier = 2.2;
  static const int _defaultPerTonMRU = 140;

  // Default shipment multipliers
  static const Map<String, double> _defaultShipmentMultipliers = {
    'generalGoodsAndBoxes': 1.00,
    'foodAndPerishables': 1.10,
    'electricalAndHomeAppliances': 1.25,
    'furnitureAndHomeSetup': 1.30,
    'fragileOrSensitiveCargo': 1.40,
    'constructionMaterialsAndHeavyLoad': 1.60,
  };

  // Default weight costs
  static const Map<String, int> _defaultWeightCosts = {
    'halfTon': 70,
    'oneTon': 140,
    'oneAndHalfTon': 210,
    'twoTons': 280,
  };

  // --- Runtime overridable values ---
  static int _base = _defaultBase;
  static int _perKm = _defaultPerKm;
  static int _minFare = _defaultMinFare;
  static double _antigravityMultiplier = _defaultAntigravityMultiplier;
  static int _perTonMRU = _defaultPerTonMRU;
  static Map<String, double> _shipmentMultipliers = Map.from(_defaultShipmentMultipliers);
  static Map<String, int> _weightCosts = Map.from(_defaultWeightCosts);

  /// Current active values (dynamic or default)
  static int get base => _base;
  static int get perKm => _perKm;
  static int get minFare => _minFare;
  static double get antigravityMultiplier => _antigravityMultiplier;
  static int get perTonMRU => _perTonMRU;
  static Map<String, double> get shipmentMultipliers => _shipmentMultipliers;
  static Map<String, int> get weightCosts => _weightCosts;

  /// Get multiplier for a specific shipment type (by enum name)
  static double getShipmentMultiplier(String typeName) => _shipmentMultipliers[typeName] ?? 1.0;

  /// Get weight cost for a specific cargo weight (by enum name)
  static int getWeightCost(String weightName) => _weightCosts[weightName] ?? 70;

  /// Whether config has been loaded from remote at least once.
  static bool _loaded = false;
  static bool get isLoaded => _loaded;

  /// Load pricing config from a Firestore document map.
  static void loadFromMap(Map<String, dynamic> data) {
    _base = (data['baseFare'] as num?)?.toInt() ?? _defaultBase;
    _perKm = (data['perKmRate'] as num?)?.toInt() ?? _defaultPerKm;
    _minFare = (data['minimumFare'] as num?)?.toInt() ?? _defaultMinFare;
    _antigravityMultiplier = (data['antigravityMultiplier'] as num?)?.toDouble() ?? _defaultAntigravityMultiplier;
    _perTonMRU = (data['perTonMRU'] as num?)?.toInt() ?? _defaultPerTonMRU;

    // Load shipment multipliers
    if (data['shipmentMultipliers'] is Map) {
      final raw = data['shipmentMultipliers'] as Map;
      _shipmentMultipliers = Map.from(_defaultShipmentMultipliers);
      for (final entry in raw.entries) {
        _shipmentMultipliers[entry.key.toString()] = (entry.value as num).toDouble();
      }
    }

    // Load weight costs
    if (data['weightCosts'] is Map) {
      final raw = data['weightCosts'] as Map;
      _weightCosts = Map.from(_defaultWeightCosts);
      for (final entry in raw.entries) {
        _weightCosts[entry.key.toString()] = (entry.value as num).toInt();
      }
    }

    _loaded = true;
  }

  /// Reset to hardcoded defaults (useful for testing).
  static void resetToDefaults() {
    _base = _defaultBase;
    _perKm = _defaultPerKm;
    _minFare = _defaultMinFare;
    _antigravityMultiplier = _defaultAntigravityMultiplier;
    _perTonMRU = _defaultPerTonMRU;
    _shipmentMultipliers = Map.from(_defaultShipmentMultipliers);
    _weightCosts = Map.from(_defaultWeightCosts);
    _loaded = false;
  }
}

/// Pricing calculation logic shared across all WawApp apps.
class Pricing {
  /// Round to nearest 5 MRU
  static int roundTo5(num v) => (v / 5).round() * 5;

  /// Compute base price without shipment type adjustment
  static ({int total, int base, int distancePart, int rounded, double km}) compute(double km) {
    final base = PricingConfig.base;
    final distancePart = (PricingConfig.perKm * km).round();
    final total = base + distancePart;
    final withMin = total < PricingConfig.minFare ? PricingConfig.minFare : total;
    final rounded = roundTo5(withMin);
    return (total: total, base: base, distancePart: distancePart, rounded: rounded, km: km);
  }

  /// Compute price WITH shipment type multiplier + antigravity factor + cargo weight.
  ///
  /// Formula:
  ///   subtotal = (base + distancePart) x shipmentMultiplier x antigravityMultiplier
  ///   subtotal = max(subtotal, minFare)
  ///   rounded  = roundTo5(subtotal)
  ///   finalPrice = rounded + weightCost
  static PricingBreakdown computeWithShipmentType(double km, ShipmentType? shipmentType, {CargoWeight? cargoWeight}) {
    final base = PricingConfig.base;
    final distancePart = (PricingConfig.perKm * km).round();
    final rawTotal = base + distancePart;

    // Apply shipment type multiplier (dynamic from config)
    final type = shipmentType ?? ShipmentTypeExtension.defaultType;
    final multiplier = PricingConfig.getShipmentMultiplier(type.name);
    final afterShipment = rawTotal * multiplier;

    // Apply antigravity factor
    final afterAntigravity = afterShipment * PricingConfig.antigravityMultiplier;

    // Apply minimum fare
    final withMin = afterAntigravity < PricingConfig.minFare ? PricingConfig.minFare.toDouble() : afterAntigravity;

    // Round to nearest 5 (before adding weight cost)
    final rounded = roundTo5(withMin);

    // Weight cost (dynamic from config)
    final selectedWeight = cargoWeight ?? CargoWeightExtension.defaultWeight;
    final weightCost = PricingConfig.getWeightCost(selectedWeight.name);

    return (
      total: rawTotal,
      base: base,
      distancePart: distancePart,
      rawTotal: rawTotal,
      rounded: rounded,
      km: km,
      multiplier: multiplier,
      adjustedTotal: afterAntigravity.round(),
      weightCost: weightCost,
      weightTons: selectedWeight.tons,
    );
  }
}
