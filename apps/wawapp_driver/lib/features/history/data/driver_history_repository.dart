import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:core_shared/core_shared.dart';
import 'package:flutter/foundation.dart';


class DriverHistoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Order>> watchAllHistoryOrders(String driverId) {
    // REQUIRED COMPOSITE INDEX: orders [driverId ASC, status ASC, updatedAt DESC]
    // Deploy via: firebase deploy --only firestore:indexes
    // Or create manually in Firebase Console: https://console.firebase.google.com/project/_/firestore/indexes
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          OrderStatus.completed.toFirestore(),
          OrderStatus.cancelledByClient.toFirestore(),
          OrderStatus.cancelledByDriver.toFirestore(),
        ])
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                return Order.fromFirestoreWithId(doc.id, doc.data());
              } catch (e, stack) {
                if (kDebugMode) {
                  print('[OrdersDriver] Error mapping order ${doc.id}: $e');
                  print('[OrdersDriver] Stack trace: $stack');
                  print('[OrdersDriver] Document data: ${doc.data()}');
                }
                return null;
              }
            })
            .whereType<Order>()
            .toList());
  }

  Stream<List<Order>> watchCompletedOrders(String driverId) {
    // REQUIRED COMPOSITE INDEX: orders [driverId ASC, status ASC, completedAt DESC]
    // Deploy via: firebase deploy --only firestore:indexes
    // Or create manually in Firebase Console: https://console.firebase.google.com/project/_/firestore/indexes
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: OrderStatus.completed.toFirestore())
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Order.fromFirestoreWithId(doc.id, doc.data()))
            .toList());
  }
}
