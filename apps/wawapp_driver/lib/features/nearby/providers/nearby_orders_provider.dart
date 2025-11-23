import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:core_shared/core_shared.dart';

import '../../../services/orders_service.dart';

final nearbyOrdersProvider =
    StreamProvider.family<List<Order>, Position>((ref, position) {
  final ordersService = OrdersService();
  return ordersService.getNearbyOrders(position);
});
