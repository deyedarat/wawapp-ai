import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../models/order.dart' as app_order;

class OrdersRepository {
  final FirebaseFirestore _firestore;

  OrdersRepository([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> createOrder({
    required String ownerId,
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> dropoff,
    required String pickupAddress,
    required String dropoffAddress,
    required double distanceKm,
    required int price,
  }) async {
    final docRef = await _firestore.collection('orders').add({
      'ownerId': ownerId,
      'pickup': pickup,
      'dropoff': dropoff,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'distanceKm': distanceKm,
      'price': price,
      'status': OrderStatus.assigning.toFirestore(), // 'matching'
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Stream<DocumentSnapshot> watchOrder(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }

  Stream<List<app_order.Order>> getUserOrders(String userId) {
    // REQUIRED COMPOSITE INDEX: orders [ownerId ASC, createdAt DESC]
    // Deploy via: firebase deploy --only firestore:indexes
    // Or create manually: https://console.firebase.google.com/project/wawapp-952d6/firestore/indexes
    return _firestore
        .collection('orders')
        .where('ownerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => app_order.Order.fromFirestore({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<app_order.Order>> getUserOrdersByStatus(String userId, OrderStatus status) {
    // REQUIRED COMPOSITE INDEX: orders [ownerId ASC, status ASC, createdAt DESC]
    // Deploy via: firebase deploy --only firestore:indexes
    // Or create manually: https://console.firebase.google.com/project/wawapp-952d6/firestore/indexes
    return _firestore
        .collection('orders')
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: status.toFirestore())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => app_order.Order.fromFirestore({...doc.data(), 'id': doc.id}))
            .toList());
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository();
});
