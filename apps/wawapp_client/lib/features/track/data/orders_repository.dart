import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrdersRepository {
  final FirebaseFirestore _firestore;

  OrdersRepository([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> createOrder({
    required LatLng pickup,
    required LatLng dropoff,
    required String pickupLabel,
    required String dropoffLabel,
    required double distanceKm,
    required int price,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final docRef = await _firestore.collection('orders').add({
      'ownerId': user.uid,
      'status': 'matching',
      'pickup': {
        'lat': pickup.latitude,
        'lng': pickup.longitude,
        'label': pickupLabel,
      },
      'dropoff': {
        'lat': dropoff.latitude,
        'lng': dropoff.longitude,
        'label': dropoffLabel,
      },
      'distanceKm': distanceKm,
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository();
});
