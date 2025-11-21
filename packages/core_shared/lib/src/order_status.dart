// Canonical Order Status State Machine for WawApp
//
// Firestore Storage:
// - Collection: 'orders'
// - Field: 'status' (String)
//
// Current Values Found in Codebase:
// - Client app: 'matching', 'accepted', 'onRoute', 'completed', 'cancelled'
//   Also legacy: 'pending', 'assigned', 'enRoute', 'pickedUp', 'delivering', 'delivered'
// - Driver app: 'matching', 'accepted', 'onRoute', 'completed', 'cancelled'
//
// This enum unifies both apps with a single canonical state machine.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical order status enum used across client and driver apps
enum OrderStatus {
  /// Order created, waiting for driver assignment
  requested,

  /// System is searching for available drivers
  assigning,

  /// Driver has accepted the order
  accepted,

  /// Driver is on the way to pickup/dropoff
  onRoute,

  /// Order successfully completed
  completed,

  /// Order cancelled by client
  cancelledByClient,

  /// Order cancelled by driver
  cancelledByDriver,

  /// Order expired without being accepted
  expired;

  /// Parse Firestore string value to enum
  /// Supports legacy values for backwards compatibility
  static OrderStatus fromFirestore(String value) {
    switch (value) {
      case 'requested':
        return OrderStatus.requested;
      case 'assigning':
      case 'matching': // Legacy
        return OrderStatus.assigning;
      case 'accepted':
      case 'assigned': // Legacy
        return OrderStatus.accepted;
      case 'onRoute':
      case 'enRoute': // Legacy
      case 'pickedUp': // Legacy
      case 'delivering': // Legacy
        return OrderStatus.onRoute;
      case 'completed':
      case 'delivered': // Legacy
        return OrderStatus.completed;
      case 'cancelledByClient':
        return OrderStatus.cancelledByClient;
      case 'cancelledByDriver':
      case 'cancelled': // Legacy - assume driver cancelled
        return OrderStatus.cancelledByDriver;
      case 'expired':
        return OrderStatus.expired;
      default:
        throw ArgumentError('Unknown order status: $value');
    }
  }

  /// Convert enum to Firestore string value
  String toFirestore() {
    switch (this) {
      case OrderStatus.requested:
        return 'requested';
      case OrderStatus.assigning:
        return 'matching'; // Keep 'matching' for compatibility
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.onRoute:
        return 'onRoute';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelledByClient:
        return 'cancelledByClient';
      case OrderStatus.cancelledByDriver:
        return 'cancelled'; // Keep 'cancelled' for compatibility
      case OrderStatus.expired:
        return 'expired';
    }
  }

  /// Get Arabic label for UI display
  String toArabicLabel() {
    switch (this) {
      case OrderStatus.requested:
        return 'قيد الإنشاء';
      case OrderStatus.assigning:
        return 'جارِ التعيين';
      case OrderStatus.accepted:
        return 'تم التعيين';
      case OrderStatus.onRoute:
        return 'في الطريق';
      case OrderStatus.completed:
        return 'تم';
      case OrderStatus.cancelledByClient:
        return 'ألغاه العميل';
      case OrderStatus.cancelledByDriver:
        return 'ألغاه السائق';
      case OrderStatus.expired:
        return 'منتهي الصلاحية';
    }
  }

  /// Check if driver can start trip from this status
  bool get canDriverStartTrip => this == OrderStatus.accepted;

  /// Check if driver can complete trip from this status
  bool get canDriverCompleteTrip => this == OrderStatus.onRoute;

  /// Check if driver can cancel from this status
  bool get canDriverCancel =>
      this == OrderStatus.accepted || this == OrderStatus.onRoute;

  /// Check if client can cancel from this status
  bool get canClientCancel =>
      this == OrderStatus.requested ||
      this == OrderStatus.assigning ||
      this == OrderStatus.accepted;

  /// Check if transition from current status to target status is valid
  bool canTransitionTo(OrderStatus target) {
    const transitions = {
      OrderStatus.requested: [
        OrderStatus.assigning,
        OrderStatus.cancelledByClient
      ],
      OrderStatus.assigning: [
        OrderStatus.accepted,
        OrderStatus.expired,
        OrderStatus.cancelledByClient
      ],
      OrderStatus.accepted: [
        OrderStatus.onRoute,
        OrderStatus.cancelledByDriver,
        OrderStatus.cancelledByClient
      ],
      OrderStatus.onRoute: [
        OrderStatus.completed,
        OrderStatus.cancelledByDriver
      ],
      OrderStatus.completed: <OrderStatus>[],
      OrderStatus.cancelledByClient: <OrderStatus>[],
      OrderStatus.cancelledByDriver: <OrderStatus>[],
      OrderStatus.expired: <OrderStatus>[],
    };
    return transitions[this]?.contains(target) ?? false;
  }

  /// Create Firestore update map for status transition
  Map<String, dynamic> createTransitionUpdate({
    String? driverId,
  }) {
    final update = <String, dynamic>{
      'status': toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Add both driverId and assignedDriverId when accepting order
    if (this == OrderStatus.accepted && driverId != null) {
      update['driverId'] = driverId;
      update['assignedDriverId'] = driverId;
    }

    // Add completedAt when completing order
    if (this == OrderStatus.completed) {
      update['completedAt'] = FieldValue.serverTimestamp();
    }

    return update;
  }
}
