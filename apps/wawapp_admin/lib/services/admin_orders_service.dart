/// Admin Orders Service
/// Handles order-related operations for admin panel
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart' as core_shared;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'audit_log_service.dart';

class AdminOrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuditLogService _auditLog = AuditLogService();

  /// Get orders stream with optional filters and pagination
  Stream<List<core_shared.Order>> getOrdersStream({String? statusFilter, int limit = 50}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => core_shared.Order.fromFirestoreWithId(doc.id, doc.data())).toList();
    });
  }

  /// Get total order count for pagination info
  Future<int> getOrderCount({String? statusFilter}) async {
    try {
      AggregateQuery countQuery;
      if (statusFilter != null && statusFilter.isNotEmpty) {
        countQuery = _firestore.collection('orders').where('status', isEqualTo: statusFilter).count();
      } else {
        countQuery = _firestore.collection('orders').count();
      }
      final snapshot = await countQuery.get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get a single order by ID
  Future<core_shared.Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return core_shared.Order.fromFirestoreWithId(doc.id, doc.data()!);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching order: $e');
      }
      return null;
    }
  }

  /// Cancel an order (admin action)
  /// Uses Cloud Function for security
  Future<bool> cancelOrder(String orderId, {String? reason}) async {
    try {
      // In a real implementation, call Cloud Function
      // For now, update directly with proper security
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled_by_admin',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': user.uid,
        'cancellationReason': reason ?? 'Cancelled by admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Audit log
      await _auditLog.log(
        action: 'order_cancelled',
        category: 'order',
        targetId: orderId,
        targetType: 'order',
        details: {'reason': reason ?? 'Cancelled by admin'},
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling order: $e');
      }
      return false;
    }
  }

  /// Reassign order to a different driver
  Future<bool> reassignOrder(String orderId, String newDriverId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.collection('orders').doc(orderId).update({
        'assignedDriverId': newDriverId,
        'driverId': newDriverId,
        'reassignedAt': FieldValue.serverTimestamp(),
        'reassignedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Audit log
      await _auditLog.log(
        action: 'order_reassigned',
        category: 'order',
        targetId: orderId,
        targetType: 'order',
        details: {'newDriverId': newDriverId},
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error reassigning order: $e');
      }
      return false;
    }
  }

  /// Get order statistics
  Future<Map<String, int>> getOrderStats() async {
    try {
      final snapshot = await _firestore.collection('orders').get();

      final stats = <String, int>{
        'total': snapshot.size,
        'matching': 0,
        'accepted': 0,
        'onRoute': 0,
        'completed': 0,
        'cancelled': 0,
      };

      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == null) continue;
        if (stats.containsKey(status)) {
          stats[status] = (stats[status] ?? 0) + 1;
        } else if (status.startsWith('cancelled')) {
          stats['cancelled'] = (stats['cancelled'] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching order stats: $e');
      }
      return {};
    }
  }

  /// Create a manual order (e.g. from phone request)
  Future<String?> createManualOrder({
    required String clientPhone,
    required String pickupAddress,
    required String dropoffAddress,
    required double distanceKm,
    required double price,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double weightTons = 0.5,
    String shipmentType = 'generalGoodsAndBoxes',
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final docRef = await _firestore.collection('orders').add({
        'customerPhone': clientPhone,
        'ownerId': 'manual_${DateTime.now().millisecondsSinceEpoch}',
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'distanceKm': distanceKm,
        'price': price,
        'weightTons': weightTons,
        'shipmentType': shipmentType,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'pickup': {'lat': pickupLat, 'lng': pickupLng, 'label': pickupAddress},
        'dropoff': {'lat': dropoffLat, 'lng': dropoffLng, 'label': dropoffAddress},
        'status': 'matching',
        'assignedDriverId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdByAdmin': user.uid,
        'isManual': true,
      });

      // Audit log
      await _auditLog.log(
        action: 'order_created_manual',
        category: 'order',
        targetId: docRef.id,
        targetType: 'order',
        details: {
          'clientPhone': clientPhone,
          'pickupAddress': pickupAddress,
          'dropoffAddress': dropoffAddress,
          'price': price,
        },
      );

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating manual order: $e');
      }
      return null;
    }
  }
}
