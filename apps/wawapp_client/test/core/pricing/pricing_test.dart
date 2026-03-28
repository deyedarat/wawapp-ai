import 'package:flutter_test/flutter_test.dart';
import 'package:wawapp_client/core/pricing/pricing.dart';
import 'package:wawapp_client/core/models/cargo_weight.dart';
import 'package:wawapp_client/core/models/shipment_type.dart';

void main() {
  group('PricingConfig', () {
    test('antigravityMultiplier is 2.2', () {
      expect(PricingConfig.antigravityMultiplier, 2.2);
    });

    test('perTonMRU is 140', () {
      expect(PricingConfig.perTonMRU, 140);
    });
  });

  group('CargoWeight', () {
    test('halfTon costs 70 MRU and weighs 0.5 tons', () {
      expect(CargoWeight.halfTon.costMRU, 70);
      expect(CargoWeight.halfTon.tons, 0.5);
    });

    test('oneTon costs 140 MRU and weighs 1.0 tons', () {
      expect(CargoWeight.oneTon.costMRU, 140);
      expect(CargoWeight.oneTon.tons, 1.0);
    });

    test('oneAndHalfTon costs 210 MRU and weighs 1.5 tons', () {
      expect(CargoWeight.oneAndHalfTon.costMRU, 210);
      expect(CargoWeight.oneAndHalfTon.tons, 1.5);
    });

    test('twoTons costs 280 MRU and weighs 2.0 tons', () {
      expect(CargoWeight.twoTons.costMRU, 280);
      expect(CargoWeight.twoTons.tons, 2.0);
    });

    test('defaultWeight is halfTon', () {
      expect(CargoWeightExtension.defaultWeight, CargoWeight.halfTon);
    });
  });

  group('Pricing.computeWithShipmentType — antigravity formula', () {
    // Formula: finalPrice = roundTo5((base + distancePart) × shipmentMultiplier × 2.2) + weightCost

    test('5km, general goods, halfTon', () {
      // base=60, dist=100, total=160
      // × 1.0 × 2.2 = 352 → roundTo5(352) = 350
      // + 70 (halfTon) → display = 420
      final b = Pricing.computeWithShipmentType(
        5.0,
        ShipmentType.generalGoodsAndBoxes,
        cargoWeight: CargoWeight.halfTon,
      );
      expect(b.base, 60);
      expect(b.distancePart, 100);
      expect(b.multiplier, 1.0);
      expect(b.rounded, 350);
      expect(b.weightCost, 70);
      expect(b.weightTons, 0.5);
    });

    test('5km, general goods, oneTon — new price is ~2.2× old base price', () {
      // old (no antigravity, no weight): roundTo5(160 × 1.0) = 160
      // new: roundTo5(160 × 2.2) = roundTo5(352) = 350, + 140 = 490
      final b = Pricing.computeWithShipmentType(
        5.0,
        ShipmentType.generalGoodsAndBoxes,
        cargoWeight: CargoWeight.oneTon,
      );
      expect(b.rounded, 350);
      expect(b.weightCost, 140);
      // ratio of subtotal to old price
      expect(b.rounded / 160, closeTo(2.1875, 0.01)); // ≈ 2.2
    });

    test('10km, construction, twoTons', () {
      // base=60, dist=200, total=260
      // × 1.6 = 416 × 2.2 = 915.2 → roundTo5(915.2) = 915
      // + 280 → display = 1195
      final b = Pricing.computeWithShipmentType(
        10.0,
        ShipmentType.constructionMaterialsAndHeavyLoad,
        cargoWeight: CargoWeight.twoTons,
      );
      expect(b.multiplier, 1.6);
      expect(b.rounded, 915);
      expect(b.weightCost, 280);
    });

    test('default weight (no cargoWeight param) uses halfTon', () {
      final b = Pricing.computeWithShipmentType(
        5.0,
        ShipmentType.generalGoodsAndBoxes,
      );
      expect(b.weightCost, 70);
      expect(b.weightTons, 0.5);
    });

    test('minimum fare applies before weight cost', () {
      // 0.1km: base=60, dist=2, total=62
      // × 1.0 × 2.2 = 136.4 → above minFare(100) → roundTo5(136.4) = 135
      // + 70 halfTon
      final b = Pricing.computeWithShipmentType(
        0.1,
        ShipmentType.generalGoodsAndBoxes,
        cargoWeight: CargoWeight.halfTon,
      );
      expect(b.rounded, greaterThanOrEqualTo(100));
      expect(b.weightCost, 70);
    });

    test('PricingBreakdown includes all required fields', () {
      final b = Pricing.computeWithShipmentType(
        3.0,
        ShipmentType.foodAndPerishables,
        cargoWeight: CargoWeight.oneTon,
      );
      // Verify all fields exist and are valid
      expect(b.base, isA<int>());
      expect(b.distancePart, isA<int>());
      expect(b.total, isA<int>());
      expect(b.rounded, isA<int>());
      expect(b.km, 3.0);
      expect(b.multiplier, isA<double>());
      expect(b.adjustedTotal, isA<int>());
      expect(b.weightCost, isA<int>());
      expect(b.weightTons, isA<double>());
    });
  });
}
