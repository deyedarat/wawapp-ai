import 'package:core_shared/core_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/testlab_flags.dart';
import '../../../core/config/testlab_mock_data.dart';
import '../../../services/orders_service.dart';

final nearbyOrdersProvider = FutureProvider.family.autoDispose<List<Order>, Position>((ref, position) async {
  print('[NEARBY_PROVIDER] 🚀 Provider callback STARTED');
  print('[NEARBY_PROVIDER] 📍 Position: lat=${position.latitude.toStringAsFixed(6)}, lng=${position.longitude.toStringAsFixed(6)}');

  // Return mock nearby orders for Test Lab mode
  if (TestLabFlags.safeEnabled) {
    print('[NEARBY_PROVIDER] 🧪 TestLab mode - returning mock data');
    return TestLabMockData.mockNearbyOrders;
  }

  final ordersService = ref.watch(ordersServiceProvider);

  print('[NEARBY_PROVIDER] 📞 Calling getNearbyOrders Cloud Function...');

  final orders = await ordersService.getNearbyOrders(position);

  print('[NEARBY_PROVIDER] ✅ Received ${orders.length} orders from Cloud Function');

  return orders;
});
