import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/shipment_type.dart';
import '../../core/models/cargo_weight.dart';

/// Provider for the currently selected shipment type
/// Defaults to generalGoodsAndBoxes as the safe default
final selectedShipmentTypeProvider = StateProvider<ShipmentType>((ref) {
  return ShipmentTypeExtension.defaultType;
});

/// Provider for the currently selected cargo weight
/// Defaults to halfTon
final selectedCargoWeightProvider = StateProvider<CargoWeight>((ref) {
  return CargoWeightExtension.defaultWeight;
});
