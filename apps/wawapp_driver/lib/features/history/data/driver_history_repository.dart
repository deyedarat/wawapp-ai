import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import '../../../models/order.dart' as app_order;

class DriverHistoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<app_order.Order>> watchCompletedOrders(String driverId) {
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => app_order.Order.fromFirestore(doc.id, doc.data()))
            .toList());
  }
}