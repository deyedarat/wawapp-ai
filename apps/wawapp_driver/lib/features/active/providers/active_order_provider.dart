import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart' as app_order;
import '../../../services/orders_service.dart';

final activeOrdersProvider = StreamProvider<List<app_order.Order>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  final ordersService = OrdersService();
  return ordersService.getDriverActiveOrders(user.uid);
});
