import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/notifications_dropdown.dart';

// ============================================================================
// Admin Notification Service
// ============================================================================

class AdminNotificationsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'notifications';
  static const String _adminUserId = 'admin';

  /// Stream of admin notifications, newest first, max 50
  Stream<List<AdminNotification>> getNotificationsStream() {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: _adminUserId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => _fromFirestore(doc))
            .whereType<AdminNotification>()
            .toList());
  }

  /// Stream of unread count
  Stream<int> getUnreadCountStream() {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: _adminUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark all admin notifications as read
  Future<void> markAllAsRead() async {
    final snap = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: _adminUserId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  AdminNotification? _fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] as String? ?? 'system';
      final createdAt = data['createdAt'];

      return AdminNotification(
        id: doc.id,
        title: data['title'] as String? ?? '',
        message: data['body'] as String? ?? '',
        icon: _iconForType(type),
        color: _colorForType(type),
        timestamp: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
        isRead: data['isRead'] as bool? ?? false,
        actionRoute: _routeForType(type, data['data'] as Map<String, dynamic>?),
      );
    } catch (_) {
      return null;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_order':
        return Icons.local_shipping;
      case 'new_driver':
        return Icons.person_add;
      case 'expired_order':
        return Icons.timer_off;
      case 'topup_request':
        return Icons.account_balance_wallet;
      case 'payout_request':
        return Icons.payments;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'new_order':
        return const Color(0xFF00704A); // primaryGreen
      case 'new_driver':
        return const Color(0xFF2196F3); // accentBlue
      case 'expired_order':
        return const Color(0xFFF44336); // red
      case 'topup_request':
      case 'payout_request':
        return const Color(0xFFFF9800); // orange
      default:
        return const Color(0xFF607D8B); // grey
    }
  }

  String? _routeForType(String type, Map<String, dynamic>? data) {
    switch (type) {
      case 'new_order':
      case 'expired_order':
        return '/orders';
      case 'new_driver':
        return '/drivers';
      case 'topup_request':
      case 'payout_request':
        return '/finance/wallets';
      default:
        return null;
    }
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

final adminNotificationsServiceProvider =
    Provider<AdminNotificationsService>((ref) {
  return AdminNotificationsService();
});

/// Stream of admin notifications list
final adminNotificationsStreamProvider =
    StreamProvider<List<AdminNotification>>((ref) {
  final service = ref.watch(adminNotificationsServiceProvider);
  return service.getNotificationsStream();
});

/// Stream of unread notifications count
final adminUnreadCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(adminNotificationsServiceProvider);
  return service.getUnreadCountStream();
});
