import 'package:core_shared/core_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/testlab_flags.dart';
import '../../../core/config/testlab_mock_data.dart';
import '../../../services/orders_service.dart';

final nearbyOrdersProvider = FutureProvider.family.autoDispose<List<Order>, Position>((ref, position) async {
  // Return mock nearby orders for Test Lab mode
  if (TestLabFlags.safeEnabled) {
    return TestLabMockData.mockNearbyOrders;
  }

  final ordersService = ref.watch(ordersServiceProvider);
  return ordersService.getNearbyOrders(position);
});
