import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:core_shared/core_shared.dart';
import '../../../models/order.dart' as app_order;

class DriverEarningsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<app_order.Order>> watchCompletedOrdersForDriver(String driverId) {
    debugPrint(
        '[EARNINGS] Starting query for completed orders, driverId: $driverId');

    // REQUIRED COMPOSITE INDEX: orders [driverId ASC, status ASC, completedAt DESC]
    // Deploy via: firebase deploy --only firestore:indexes
    // Or create manually in Firebase Console: https://console.firebase.google.com/project/_/firestore/indexes
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: OrderStatus.completed.toFirestore())
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => app_order.Order.fromFirestore(doc.id, doc.data()))
          .toList();

      debugPrint('[EARNINGS] Fetched ${orders.length} completed orders');
      return orders;
    });
  }

  List<app_order.Order> getDailyEarnings(List<app_order.Order> orders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return orders.where((order) {
      final completedAt = order.completedAt;
      return completedAt != null &&
          completedAt.isAfter(today) &&
          completedAt.isBefore(tomorrow);
    }).toList();
  }

  int totalForToday(List<app_order.Order> orders) {
    final todayOrders = getDailyEarnings(orders);
    final total = todayOrders.fold<int>(0, (acc, order) => acc + order.price);
    debugPrint(
        '[EARNINGS] Today total: $total MRU from ${todayOrders.length} orders');
    return total;
  }

  List<app_order.Order> getWeeklyEarnings(List<app_order.Order> orders) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    return orders.where((order) {
      final completedAt = order.completedAt;
      return completedAt != null && completedAt.isAfter(weekStartDay);
    }).toList();
  }

  int totalForCurrentWeek(List<app_order.Order> orders) {
    final weekOrders = getWeeklyEarnings(orders);
    final total = weekOrders.fold<int>(0, (acc, order) => acc + order.price);
    debugPrint(
        '[EARNINGS] Week total: $total MRU from ${weekOrders.length} orders');
    return total;
  }

  int totalForCurrentMonth(List<app_order.Order> orders) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final monthOrders = orders.where((order) {
      final completedAt = order.completedAt;
      return completedAt != null && completedAt.isAfter(monthStart);
    }).toList();

    final total = monthOrders.fold<int>(0, (acc, order) => acc + order.price);
    debugPrint(
        '[EARNINGS] Month total: $total MRU from ${monthOrders.length} orders');
    return total;
  }
}
