# Driver Tracking System - Complete Code Reference

## Overview
This document contains all code responsible for:
1. Sending live driver location updates to Firestore
2. Updating order status (accepted → onRoute → completed)
3. Streaming driver data to the client side

---

## 1. DRIVER APP - Location Tracking

### 1.1 Location Service
**File**: `apps/wawapp_driver/lib/services/location_service.dart`

```dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Position? _lastPosition;

  Future<Position> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Location services disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    _lastPosition = await Geolocator.getCurrentPosition();
    return _lastPosition!;
  }

  Position? get lastPosition => _lastPosition;
}
```

**Key Features**:
- Singleton pattern for global access
- Handles location permissions
- Caches last known position

---

### 1.2 Tracking Service (Live Location Updates)
**File**: `apps/wawapp_driver/lib/services/tracking_service.dart`

```dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import 'orders_service.dart';

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService.instance;
  final OrdersService _ordersService = OrdersService();

  StreamSubscription? _orderSubscription;
  Timer? _updateTimer;
  Position? _lastPosition;
  bool _isTracking = false;

  void startTracking() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isTracking) {
      return;
    }

    dev.log('[tracking] start');
    _isTracking = true;

    _orderSubscription =
        _ordersService.getDriverActiveOrders(user.uid).listen((orders) {
      if (orders.isNotEmpty) {
        _startLocationUpdates(user.uid);
      } else {
        _stopLocationUpdates();
      }
    });
  }

  void stopTracking() {
    if (!_isTracking) {
      return;
    }

    dev.log('[tracking] stop');
    _isTracking = false;
    _stopLocationUpdates();
    _orderSubscription?.cancel();
  }

  void _startLocationUpdates(String driverId) {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final position = await _locationService.getCurrentPosition();

        if (_lastPosition != null) {
          final distance = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          if (distance < 20) {
            return; // Skip if moved less than 20m
          }
        }

        await _firestore.collection('driver_locations').doc(driverId).set({
          'lat': position.latitude,
          'lng': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        _lastPosition = position;
        dev.log(
            '[tracking] update lat=${position.latitude} lng=${position.longitude}');
      } on Object catch (e) {
        dev.log('[tracking] error: $e');
      }
    });
  }

  void _stopLocationUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _lastPosition = null;
  }
}
```

**Key Features**:
- Updates driver location every 5 seconds
- Only updates if driver moved >20 meters (optimization)
- Writes to Firestore collection: `driver_locations/{driverId}`
- Automatically starts/stops based on active orders
- Uses singleton pattern

**Firestore Structure**:
```
driver_locations/{driverId}
  ├── lat: double
  ├── lng: double
  └── updatedAt: timestamp
```

---

## 2. DRIVER APP - Order Status Management

### 2.1 Orders Service
**File**: `apps/wawapp_driver/lib/services/orders_service.dart`

```dart
import 'dart:developer' as dev;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:core_shared/core_shared.dart';
import '../models/order.dart' as app_order;

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<app_order.Order>> getNearbyOrders(Position driverPosition) {
    dev.log('[nearby_stream] start');

    return _firestore
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.assigning.toFirestore())
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        dev.log('[nearby_stream] empty');
        return <app_order.Order>[];
      }

      final orders = <app_order.Order>[];
      for (final doc in snapshot.docs) {
        try {
          final order = app_order.Order.fromFirestore(doc.id, doc.data());
          final distance = _calculateDistance(
            driverPosition.latitude,
            driverPosition.longitude,
            order.pickup.lat,
            order.pickup.lng,
          );

          if (distance <= 8.0) {
            orders.add(order);
            dev.log(
                '[nearby_stream] item: {id: ${order.id}, km: ${distance.toStringAsFixed(1)}, price: ${order.price}}');
          }
        } on Object catch (e) {
          dev.log('[nearby_stream] error parsing order ${doc.id}: $e');
        }
      }

      orders.sort((a, b) {
        final distA = _calculateDistance(
          driverPosition.latitude,
          driverPosition.longitude,
          a.pickup.lat,
          a.pickup.lng,
        );
        final distB = _calculateDistance(
          driverPosition.latitude,
          driverPosition.longitude,
          b.pickup.lat,
          b.pickup.lng,
        );
        return distA.compareTo(distB);
      });

      return orders;
    }).handleError((error) {
      dev.log('[nearby_stream] error: $error');
      return <app_order.Order>[];
    });
  }

  Future<void> acceptOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Driver not authenticated');
    }

    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final currentStatus = OrderStatus.fromFirestore(
          orderDoc.data()!['status'] as String);
      if (currentStatus != OrderStatus.assigning) {
        throw Exception('Order was already taken');
      }

      final update = OrderStatus.accepted.createTransitionUpdate(
        driverId: user.uid,
      );

      transaction.update(orderRef, update);
    });
  }

  Future<void> transition(String orderId, OrderStatus to) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final currentStatus = OrderStatus.fromFirestore(
          orderDoc.data()!['status'] as String);

      if (!currentStatus.canTransitionTo(to)) {
        throw Exception('Invalid status transition');
      }

      final update = to.createTransitionUpdate();
      transaction.update(orderRef, update);
    });
  }

  Stream<List<app_order.Order>> getDriverActiveOrders(String driverId) {
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          OrderStatus.accepted.toFirestore(),
          OrderStatus.onRoute.toFirestore(),
        ])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => app_order.Order.fromFirestore(doc.id, doc.data()))
              .toList();
        });
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth radius in km
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
```

**Key Methods**:
- `getNearbyOrders()`: Streams orders within 8km radius
- `acceptOrder()`: Transitions order from `assigning` → `accepted`
- `transition()`: Updates order status with validation
- `getDriverActiveOrders()`: Streams driver's active orders

**Status Transitions**:
```
requested → assigning → accepted → onRoute → completed
                    ↓
              cancelledByDriver
```

---

### 2.2 Order Model
**File**: `apps/wawapp_driver/lib/models/order.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';

class Order {
  final String id;
  final String ownerId;
  final String status;
  final LocationPoint pickup;
  final LocationPoint dropoff;
  final double distanceKm;
  final int price;
  final DateTime? createdAt;
  final String? driverId;

  const Order({
    required this.id,
    required this.ownerId,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.price,
    this.createdAt,
    this.driverId,
  });

  OrderStatus get orderStatus => OrderStatus.fromFirestore(status);

  factory Order.fromFirestore(String id, Map<String, dynamic> data) {
    return Order(
      id: id,
      ownerId: data['ownerId'] as String,
      status: data['status'] as String,
      pickup: LocationPoint.fromMap(data['pickup'] as Map<String, dynamic>),
      dropoff: LocationPoint.fromMap(data['dropoff'] as Map<String, dynamic>),
      distanceKm: (data['distanceKm'] as num).toDouble(),
      price: data['price'] as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      driverId: data['driverId'] as String?,
    );
  }
}

class LocationPoint {
  final double lat;
  final double lng;
  final String label;

  const LocationPoint({
    required this.lat,
    required this.lng,
    required this.label,
  });

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      label: map['label'] as String,
    );
  }
}
```

---

### 2.3 Active Order Screen (UI for Status Updates)
**File**: `apps/wawapp_driver/lib/features/active/active_order_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart';
import '../../models/order.dart' as app_order;
import '../../services/orders_service.dart';

class ActiveOrderScreen extends StatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final _ordersService = OrdersService();

  Future<void> _transition(String orderId, OrderStatus to) async {
    try {
      await _ordersService.transition(orderId, to);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة الطلب')),
      );
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('غير مسجل الدخول')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الطلب النشط')),
      body: StreamBuilder<List<app_order.Order>>(
        stream: _ordersService.getDriverActiveOrders(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد طلبات نشطة'),
                ],
              ),
            );
          }

          final order = orders.first;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('طلب #${order.id.substring(order.id.length - 6)}',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text('من: ${order.pickup.label}'),
                        Text('إلى: ${order.dropoff.label}'),
                        Text(
                            'المسافة: ${order.distanceKm.toStringAsFixed(1)} كم'),
                        Text('السعر: ${order.price} MRU'),
                        Text('الحالة: ${order.orderStatus.toArabicLabel()}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: order.orderStatus.canDriverStartTrip
                      ? () => _transition(order.id, OrderStatus.onRoute)
                      : null,
                  child: const Text('بدء الرحلة'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: order.orderStatus.canDriverCompleteTrip
                      ? () => _transition(order.id, OrderStatus.completed)
                      : null,
                  child: const Text('إكمال الطلب'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: order.orderStatus.canDriverCancel
                      ? () => _transition(order.id, OrderStatus.cancelledByDriver)
                      : null,
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

**UI Actions**:
- "بدء الرحلة" (Start Trip): `accepted` → `onRoute`
- "إكمال الطلب" (Complete): `onRoute` → `completed`
- "إلغاء" (Cancel): Any → `cancelledByDriver`

---

## 3. CLIENT APP - Streaming Driver Data

### 3.1 Order Tracking Provider
**File**: `apps/wawapp_client/lib/features/track/providers/order_tracking_provider.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final orderTrackingProvider =
    StreamProvider.family<DocumentSnapshot?, String>((ref, orderId) {
  return FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots();
});
```

**Key Features**:
- Riverpod StreamProvider for real-time updates
- Family modifier allows tracking multiple orders
- Returns Firestore DocumentSnapshot stream

---

### 3.2 Driver Found Screen
**File**: `apps/wawapp_client/lib/features/track/driver_found_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/order_tracking_provider.dart';

class DriverFoundScreen extends ConsumerWidget {
  final String orderId;

  const DriverFoundScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderTrackingProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('تم العثور على سائق')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('خطأ: $error'),
        ),
        data: (snapshot) {
          if (snapshot == null || !snapshot.exists) {
            return const Center(child: Text('الطلب غير موجود'));
          }

          final data = snapshot.data() as Map<String, dynamic>;
          final driverId = data['driverId'] as String?;
          final status = data['status'] as String?;

          return FutureBuilder<DocumentSnapshot>(
            future: driverId != null
                ? FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(driverId)
                    .get()
                : null,
            builder: (context, driverSnapshot) {
              final driverData = driverSnapshot.data?.data() as Map<String, dynamic>?;
              final driverName = driverData?['name'] as String? ?? 'السائق';
              final driverPhone = driverData?['phone'] as String? ?? '';
              final vehicle = driverData?['vehicle'] as String? ?? 'غير محدد';

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.check_circle, size: 80, color: Colors.green),
                    const SizedBox(height: 24),
                    const Text(
                      'تم قبول طلبك!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('السائق: $driverName',
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 8),
                            if (driverPhone.isNotEmpty)
                              Text('الهاتف: $driverPhone',
                                  style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('المركبة: $vehicle',
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('الحالة: ${status ?? "غير معروف"}',
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.access_time),
                            SizedBox(width: 8),
                            Text('الوقت المتوقع للوصول: 5-10 دقائق',
                                style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        context.go('/track/$orderId');
                      },
                      child: const Text('تتبع السائق'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

**Data Flow**:
1. Watches order document via `orderTrackingProvider`
2. Extracts `driverId` from order data
3. Fetches driver details from `drivers/{driverId}`
4. Displays driver info (name, phone, vehicle)
5. Shows current order status

---

## 4. Firestore Data Structure

### 4.1 Orders Collection
```
orders/{orderId}
  ├── ownerId: string (client user ID)
  ├── driverId: string? (assigned driver ID)
  ├── status: string (requested|assigning|accepted|onRoute|completed|cancelled)
  ├── pickup: {
  │     ├── lat: double
  │     ├── lng: double
  │     └── label: string
  │   }
  ├── dropoff: {
  │     ├── lat: double
  │     ├── lng: double
  │     └── label: string
  │   }
  ├── distanceKm: double
  ├── price: int
  ├── createdAt: timestamp
  ├── acceptedAt: timestamp?
  ├── onRouteAt: timestamp?
  └── completedAt: timestamp?
```

### 4.2 Driver Locations Collection
```
driver_locations/{driverId}
  ├── lat: double
  ├── lng: double
  └── updatedAt: timestamp
```

### 4.3 Drivers Collection
```
drivers/{driverId}
  ├── name: string
  ├── phone: string
  ├── vehicle: string
  ├── rating: double?
  └── isOnline: boolean
```

---

## 5. Integration Points

### 5.1 Driver App Initialization
**File**: `apps/wawapp_driver/lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Start tracking service when driver logs in
  // TrackingService.instance.startTracking();
  
  runApp(const ProviderScope(child: MyApp()));
}
```

**Note**: TrackingService should be started when driver goes online and stopped when offline.

### 5.2 Client App Order Tracking
**File**: `apps/wawapp_client/lib/features/track/track_screen.dart`

Uses `OrderTrackingView` widget which:
- Subscribes to order updates via `orderTrackingProvider`
- Displays map with pickup/dropoff markers
- Shows order status timeline
- Can optionally show driver location (from `driver_locations` collection)

---

## 6. Missing Implementation: Driver Location on Client Map

**Current Gap**: Client app doesn't display live driver location on map.

**Required Implementation**:

```dart
// Add to OrderTrackingView
final driverLocationProvider = StreamProvider.family<DocumentSnapshot?, String>((ref, driverId) {
  return FirebaseFirestore.instance
      .collection('driver_locations')
      .doc(driverId)
      .snapshots();
});

// In OrderTrackingView widget:
if (order.driverId != null) {
  final driverLocationAsync = ref.watch(driverLocationProvider(order.driverId!));
  
  driverLocationAsync.whenData((snapshot) {
    if (snapshot != null && snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      final driverLat = data['lat'] as double;
      final driverLng = data['lng'] as double;
      
      // Add driver marker to map
      markers.add(Marker(
        markerId: MarkerId('driver'),
        position: LatLng(driverLat, driverLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'السائق'),
      ));
    }
  });
}
```

---

## 7. Status Transition Rules

Defined in `packages/core_shared/lib/src/order_status.dart`:

```dart
enum OrderStatus {
  requested,      // Initial state
  assigning,      // System looking for driver
  accepted,       // Driver accepted
  onRoute,        // Driver started trip
  completed,      // Trip finished
  cancelledByClient,
  cancelledByDriver,
}

extension OrderStatusX on OrderStatus {
  bool canTransitionTo(OrderStatus to) {
    switch (this) {
      case OrderStatus.requested:
        return to == OrderStatus.assigning;
      case OrderStatus.assigning:
        return to == OrderStatus.accepted || to == OrderStatus.cancelledByClient;
      case OrderStatus.accepted:
        return to == OrderStatus.onRoute || to == OrderStatus.cancelledByDriver;
      case OrderStatus.onRoute:
        return to == OrderStatus.completed || to == OrderStatus.cancelledByDriver;
      default:
        return false;
    }
  }
  
  bool get canDriverStartTrip => this == OrderStatus.accepted;
  bool get canDriverCompleteTrip => this == OrderStatus.onRoute;
  bool get canDriverCancel => this == OrderStatus.accepted || this == OrderStatus.onRoute;
}
```

---

## 8. Summary

### Driver App Flow:
1. Driver logs in → `TrackingService.startTracking()`
2. Service monitors active orders via `getDriverActiveOrders()`
3. If active order exists → starts location updates every 5 seconds
4. Location written to `driver_locations/{driverId}`
5. Driver updates order status via `OrdersService.transition()`

### Client App Flow:
1. Client creates order → status: `requested`
2. System changes to `assigning`
3. Driver accepts → status: `accepted`, `driverId` set
4. Client watches order via `orderTrackingProvider(orderId)`
5. Client can fetch driver details from `drivers/{driverId}`
6. Client can watch driver location from `driver_locations/{driverId}` (not yet implemented)

### Key Files:
- **Driver Location**: `tracking_service.dart` (writes every 5s)
- **Order Status**: `orders_service.dart` (transitions with validation)
- **Client Streaming**: `order_tracking_provider.dart` (real-time updates)
- **Status Rules**: `core_shared/order_status.dart` (shared logic)
