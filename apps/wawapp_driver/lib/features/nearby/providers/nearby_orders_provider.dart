import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:core_shared/core_shared.dart';
import '../../../services/orders_service.dart';
import '../../../core/config/testlab_flags.dart';
import '../../../core/config/testlab_mock_data.dart';

final nearbyOrdersProvider =
    StreamProvider.family.autoDispose<List<Order>, Position>((ref, position) {
  // Return mock nearby orders for Test Lab mode
  if (TestLabFlags.safeEnabled) {
    return Stream.value(TestLabMockData.mockNearbyOrders);
  }
  
  final ordersService = ref.watch(ordersServiceProvider);
  return ordersService.getNearbyOrders(position);
});
