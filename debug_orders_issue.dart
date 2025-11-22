// Debug script to identify the NearbyScreen orders issue
import 'dart:developer' as dev;

void main() {
  // Test OrderStatus enum behavior
  print('=== OrderStatus Debug ===');

  // What client creates
  final clientStatus = OrderStatus.assigning;
  print(
    'Client creates with: ${clientStatus.toFirestore()}',
  ); // Should be "matching"

  // What driver searches for
  final driverSearchStatus = OrderStatus.assigning.toFirestore();
  print('Driver searches for: $driverSearchStatus'); // Should be "matching"

  // Check if they match
  print('Status match: ${clientStatus.toFirestore() == driverSearchStatus}');

  // Check legacy compatibility
  final legacyStatus = OrderStatus.fromFirestore('matching');
  print('Legacy "matching" maps to: $legacyStatus');
  print('Legacy toFirestore: ${legacyStatus.toFirestore()}');
}

// Potential issues to investigate:
// 1. Orders might be created with different status
// 2. Distance calculation might be filtering out all orders
// 3. Firestore query might have permission issues
// 4. Orders collection might be empty
// 5. Driver location might not be available

enum OrderStatus {
  requested,
  assigning,
  accepted,
  onRoute,
  completed,
  cancelledByClient,
  cancelledByDriver,
  expired;

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
      case 'cancelled': // Legacy
        return OrderStatus.cancelledByDriver;
      case 'expired':
        return OrderStatus.expired;
      default:
        throw ArgumentError('Unknown order status: $value');
    }
  }

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
        return 'cancelled';
      case OrderStatus.expired:
        return 'expired';
    }
  }
}
