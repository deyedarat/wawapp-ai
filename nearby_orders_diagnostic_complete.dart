// Complete diagnostic for NearbyScreen orders issue
import 'dart:developer' as dev;
import 'dart:math';

void main() {
  print('=== NEARBY ORDERS DIAGNOSTIC ===\n');

  // 1. Test OrderStatus behavior
  testOrderStatusBehavior();

  // 2. Test distance calculation
  testDistanceCalculation();

  // 3. Simulate order filtering
  simulateOrderFiltering();

  // 4. Test with unlimited distance
  testUnlimitedDistance();
}

void testOrderStatusBehavior() {
  print('1. ORDER STATUS BEHAVIOR:');

  final clientStatus = OrderStatus.assigning;
  final driverSearchStatus = OrderStatus.assigning.toFirestore();

  print('   Client creates: OrderStatus.assigning');
  print('   Client Firestore value: "${clientStatus.toFirestore()}"');
  print('   Driver searches for: "${driverSearchStatus}"');
  print('   Match: ${clientStatus.toFirestore() == driverSearchStatus}');

  // Test legacy compatibility
  final legacyParsed = OrderStatus.fromFirestore('matching');
  print(
    '   Legacy "matching" → ${legacyParsed} → "${legacyParsed.toFirestore()}"',
  );
  print('');
}

void testDistanceCalculation() {
  print('2. DISTANCE CALCULATION TEST:');

  // Nouakchott coordinates (approximate city center)
  final driverLat = 18.0735;
  final driverLng = -15.9582;

  // Test locations at various distances
  final testLocations = [
    {'name': 'Same location', 'lat': 18.0735, 'lng': -15.9582},
    {'name': '1km away', 'lat': 18.0825, 'lng': -15.9582},
    {'name': '5km away', 'lat': 18.1185, 'lng': -15.9582},
    {'name': '8km away (limit)', 'lat': 18.1455, 'lng': -15.9582},
    {'name': '10km away', 'lat': 18.1635, 'lng': -15.9582},
  ];

  for (final location in testLocations) {
    final distance = calculateDistance(
      driverLat,
      driverLng,
      location['lat'] as double,
      location['lng'] as double,
    );
    final withinLimit = distance <= 8.0;
    print(
      '   ${location['name']}: ${distance.toStringAsFixed(2)}km ${withinLimit ? '✓' : '✗'}',
    );
  }
  print('');
}

void simulateOrderFiltering() {
  print('3. ORDER FILTERING SIMULATION:');

  // Simulate orders with different statuses and distances
  final mockOrders = [
    {'id': 'order1', 'status': 'matching', 'distance': 2.5},
    {'id': 'order2', 'status': 'matching', 'distance': 7.8},
    {'id': 'order3', 'status': 'matching', 'distance': 9.2},
    {'id': 'order4', 'status': 'accepted', 'distance': 3.1},
    {'id': 'order5', 'status': 'matching', 'distance': 5.0},
  ];

  print('   Total orders in Firestore: ${mockOrders.length}');

  // Filter by status
  final statusFiltered = mockOrders
      .where((order) => order['status'] == OrderStatus.assigning.toFirestore())
      .toList();
  print(
    '   After status filter (${OrderStatus.assigning.toFirestore()}): ${statusFiltered.length}',
  );

  // Filter by distance (8km limit)
  final distanceFiltered = statusFiltered
      .where((order) => (order['distance'] as double) <= 8.0)
      .toList();
  print('   After distance filter (≤8km): ${distanceFiltered.length}');

  print('   Final orders shown:');
  for (final order in distanceFiltered) {
    print('     - ${order['id']}: ${order['distance']}km');
  }
  print('');
}

void testUnlimitedDistance() {
  print('4. UNLIMITED DISTANCE TEST:');

  final mockOrders = [
    {'id': 'order1', 'status': 'matching', 'distance': 2.5},
    {'id': 'order2', 'status': 'matching', 'distance': 15.8},
    {'id': 'order3', 'status': 'matching', 'distance': 25.2},
    {'id': 'order4', 'status': 'matching', 'distance': 50.0},
  ];

  print('   With unlimited distance (no 8km filter):');
  final statusOnly = mockOrders
      .where((order) => order['status'] == OrderStatus.assigning.toFirestore())
      .toList();

  for (final order in statusOnly) {
    print('     - ${order['id']}: ${order['distance']}km');
  }
  print('   Total orders: ${statusOnly.length}');
  print('');
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Earth radius in km
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

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
      case 'matching':
        return OrderStatus.assigning;
      case 'accepted':
      case 'assigned':
        return OrderStatus.accepted;
      case 'onRoute':
      case 'enRoute':
      case 'pickedUp':
      case 'delivering':
        return OrderStatus.onRoute;
      case 'completed':
      case 'delivered':
        return OrderStatus.completed;
      case 'cancelledByClient':
        return OrderStatus.cancelledByClient;
      case 'cancelledByDriver':
      case 'cancelled':
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
        return 'matching';
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
