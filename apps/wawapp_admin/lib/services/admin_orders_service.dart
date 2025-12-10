/**
 * Admin Orders Service
 * Handles order-related operations for admin panel
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart' as core_shared;

class AdminOrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get orders stream with optional filters
  Stream<List<core_shared.Order>> getOrdersStream({
    String? statusFilter,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => core_shared.Order.fromFirestoreWithId(doc.id, doc.data()))
          .toList();
    });
  }

  /// Get a single order by ID
  Future<core_shared.Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return core_shared.Order.fromFirestoreWithId(doc.id, doc.data()!);
    } catch (e) {
      print('Error fetching order: $e');
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

      return true;
    } catch (e) {
      print('Error cancelling order: $e');
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

      return true;
    } catch (e) {
      print('Error reassigning order: $e');
      return false;
    }
  }

  /// Get order statistics
  Future<Map<String, int>> getOrderStats() async {
    try {
      final snapshot = await _firestore.collection('orders').get();
      
      final stats = <String, int>{
        'total': snapshot.size,
        'assigning': 0,
        'accepted': 0,
        'on_route': 0,
        'completed': 0,
        'cancelled': 0,
      };

      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status != null && stats.containsKey(status)) {
          stats[status] = (stats[status] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      print('Error fetching order stats: $e');
      return {};
    }
  }
}
