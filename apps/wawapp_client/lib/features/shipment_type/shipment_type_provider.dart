import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/shipment_type.dart';

/// Provider for the currently selected shipment type
/// Defaults to generalGoodsAndBoxes as the safe default
final selectedShipmentTypeProvider = StateProvider<ShipmentType>((ref) {
  return ShipmentType.defaultType;
});
