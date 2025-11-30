import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:core_shared/core_shared.dart';

import '../../../services/orders_service.dart';

final nearbyOrdersProvider =
    StreamProvider.family.autoDispose<List<Order>, Position>((ref, position) {
  final ordersService = ref.watch(ordersServiceProvider);
  return ordersService.getNearbyOrders(position);
});
