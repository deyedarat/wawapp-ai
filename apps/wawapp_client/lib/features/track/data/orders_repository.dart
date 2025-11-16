import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';

class OrdersRepository {
  final FirebaseFirestore _firestore;

  OrdersRepository([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> createOrder({
    required String ownerId,
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> dropoff,
    required double distanceKm,
    required int price,
    required OrderStatus status,
  }) async {
    final docRef = await _firestore.collection('orders').add({
      'ownerId': ownerId,
      'pickup': pickup,
      'dropoff': dropoff,
      'distanceKm': distanceKm,
      'price': price,
      'status': status.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Stream<DocumentSnapshot> watchOrder(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository();
});
