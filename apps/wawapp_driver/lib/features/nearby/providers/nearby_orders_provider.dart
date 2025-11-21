import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/order.dart' as app_order;
import '../../../services/orders_service.dart';

final nearbyOrdersProvider =
    StreamProvider.family<List<app_order.Order>, Position>((ref, position) {
  final ordersService = OrdersService();
  return ordersService.getNearbyOrders(position);
});
