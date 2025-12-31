import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';

import '../../../services/analytics_service.dart';

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
    try {
      debugPrint('[OrdersClient] Creating order for user: $ownerId');
      debugPrint(
          '[OrdersClient] Pickup: $pickupAddress, Dropoff: $dropoffAddress');

      final docRef = await _firestore.collection('orders').add({
        'ownerId': ownerId,
        'pickup': pickup,
        'dropoff': dropoff,
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'distanceKm': distanceKm,
        'price': price,
        'status': OrderStatus.assigning.toFirestore(), // 'matching'
        'assignedDriverId': null, // Ensure null for Phase A compatibility
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '[OrdersClient] Order created successfully with ID: ${docRef.id}');
      
      // Log analytics event
      AnalyticsService.instance.logOrderCreated(
        orderId: docRef.id,
        priceAmount: price,
        distanceKm: distanceKm,
      );
      
      return docRef.id;
    } catch (e, stackTrace) {
      debugPrint('[OrdersClient] Failed to create order: $e');
      debugPrint('[OrdersClient] Stack trace: $stackTrace');
      throw AppError.from(e);
    }
  }

  Stream<DocumentSnapshot> watchOrder(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }

  Stream<List<Order>> getUserOrders(String userId) {
    // REQUIRED COMPOSITE INDEX: orders [ownerId ASC, createdAt DESC]
    // Deploy via: firebase deploy --only firestore:indexes
    // Or create manually: https://console.firebase.google.com/project/wawapp-952d6/firestore/indexes
    debugPrint('[OrdersClient] Fetching all orders for user: $userId');

    return _firestore
        .collection('orders')
        .where('ownerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .handleError((error, stackTrace) {
      debugPrint('[OrdersClient] Error fetching user orders: $error');
      debugPrint('[OrdersClient] Stack trace: $stackTrace');
      throw AppError.from(error);
    }).map((snapshot) {
      debugPrint('[OrdersClient] Received ${snapshot.docs.length} orders');
      return snapshot.docs
          .map((doc) =>
              Order.fromFirestore({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  Stream<List<Order>> getUserOrdersByStatus(
      String userId, OrderStatus status) {
    // REQUIRED COMPOSITE INDEX: orders [ownerId ASC, status ASC, createdAt DESC]
    // Deploy via: firebase deploy --only firestore:indexes
    // Or create manually: https://console.firebase.google.com/project/wawapp-952d6/firestore/indexes
    debugPrint(
        '[OrdersClient] Fetching orders for user: $userId with status: ${status.toFirestore()}');

    return _firestore
        .collection('orders')
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: status.toFirestore())
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .handleError((error, stackTrace) {
      debugPrint('[OrdersClient] Error fetching orders by status: $error');
      debugPrint('[OrdersClient] Stack trace: $stackTrace');
      throw AppError.from(error);
    }).map((snapshot) {
      debugPrint(
          '[OrdersClient] Received ${snapshot.docs.length} orders with status: ${status.toFirestore()}');
      return snapshot.docs
          .map((doc) =>
              Order.fromFirestore({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw const AppError(type: AppErrorType.notFound, message: 'Order not found');
        }

        final data = orderSnapshot.data()!;
        final currentStatus = OrderStatus.fromFirestore(data['status'] as String);

        if (!currentStatus.canClientCancel) {
          throw const AppError(type: AppErrorType.permissionDenied, message: 'Cannot cancel order in current status');
        }

        transaction.update(
          orderRef,
          OrderStatus.cancelledByClient.createTransitionUpdate(),
        );
      });

      // Log analytics event after successful cancellation
      AnalyticsService.instance.logOrderCancelledByClient(orderId: orderId);
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }

  Future<void> rateDriver({
    required String orderId,
    required int rating,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw const AppError(type: AppErrorType.notFound, message: 'Order not found');
        }

        final data = orderSnapshot.data()!;
        final ownerId = data['ownerId'] as String?;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        if (ownerId != currentUserId) {
          throw const AppError(type: AppErrorType.permissionDenied, message: 'Not authorized to rate this order');
        }

        final currentStatus = OrderStatus.fromFirestore(data['status'] as String);
        if (currentStatus != OrderStatus.completed) {
          throw const AppError(type: AppErrorType.permissionDenied, message: 'Can only rate completed orders');
        }

        transaction.update(orderRef, {
          'driverRating': rating,
          'ratedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository();
});
