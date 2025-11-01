import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required String status,
  }) async {
    final docRef = await _firestore.collection('orders').add({
      'ownerId': ownerId,
      'pickup': pickup,
      'dropoff': dropoff,
      'distanceKm': distanceKm,
      'price': price,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository();
});
