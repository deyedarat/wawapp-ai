import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import 'package:core_shared/core_shared.dart';


class DriverEarningsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Order>> watchCompletedOrdersForDriver(String driverId) {
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
          .map((doc) => Order.fromFirestoreWithId(doc.id, doc.data()))
          .toList();

      debugPrint('[EARNINGS] Fetched ${orders.length} completed orders');
      return orders;
    });
  }

  List<Order> getDailyEarnings(List<Order> orders) {
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

  int totalForToday(List<Order> orders) {
    final todayOrders = getDailyEarnings(orders);
    final total = todayOrders.fold<int>(0, (acc, order) => acc + order.price.toInt());
    debugPrint(
        '[EARNINGS] Today total: $total MRU from ${todayOrders.length} orders');
    return total;
  }

  List<Order> getWeeklyEarnings(List<Order> orders) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    return orders.where((order) {
      final completedAt = order.completedAt;
      return completedAt != null && completedAt.isAfter(weekStartDay);
    }).toList();
  }

  int totalForCurrentWeek(List<Order> orders) {
    final weekOrders = getWeeklyEarnings(orders);
    final total = weekOrders.fold<int>(0, (acc, order) => acc + order.price.toInt());
    debugPrint(
        '[EARNINGS] Week total: $total MRU from ${weekOrders.length} orders');
    return total;
  }

  int totalForCurrentMonth(List<Order> orders) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final monthOrders = orders.where((order) {
      final completedAt = order.completedAt;
      return completedAt != null && completedAt.isAfter(monthStart);
    }).toList();

    final total = monthOrders.fold<int>(0, (acc, order) => acc + order.price.toInt());
    debugPrint(
        '[EARNINGS] Month total: $total MRU from ${monthOrders.length} orders');
    return total;
  }
}
