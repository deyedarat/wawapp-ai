import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';

import '../../track/data/orders_repository.dart';

/// Provider that streams all past orders (completed, cancelled, expired)
/// for the currently authenticated user.
final orderHistoryProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(ordersRepositoryProvider);
  return repository.getUserOrders(user.uid).map((orders) {
    // Filter to only terminal statuses (past orders)
    return orders.where((order) {
      final status = order.orderStatus;
      return status == OrderStatus.completed ||
          status == OrderStatus.cancelledByClient ||
          status == OrderStatus.cancelledByDriver ||
          status == OrderStatus.cancelledBySystem ||
          status == OrderStatus.cancelledByAdmin ||
          status == OrderStatus.expired;
    }).toList();
  });
});
