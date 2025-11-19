import 'dart:async';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

    debugPrint('[TRACKING] Starting tracking for driver: ${user.uid}');
    dev.log('[tracking] start');
    _isTracking = true;

    _orderSubscription =
        _ordersService.getDriverActiveOrders(user.uid).listen((orders) {
      debugPrint('[TRACKING] Active orders count: ${orders.length}');
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

    debugPrint('[TRACKING] Stopping tracking');
    dev.log('[tracking] stop');
    _isTracking = false;
    _stopLocationUpdates();
    _orderSubscription?.cancel();
  }

  void _startLocationUpdates(String driverId) {
    _updateTimer?.cancel();
    debugPrint('[TRACKING] Starting location updates for driver: $driverId');
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
            debugPrint(
                '[TRACKING] Skipping update - moved only ${distance.toStringAsFixed(1)}m');
            return; // Skip if moved less than 20m
          }
        }

        await _firestore.collection('driver_locations').doc(driverId).set({
          'lat': position.latitude,
          'lng': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint(
            '[TRACKING] Firestore write - driverId: $driverId, lat: ${position.latitude}, lng: ${position.longitude}, updatedAt: serverTimestamp');
        _lastPosition = position;
        dev.log(
            '[tracking] update lat=${position.latitude} lng=${position.longitude}');
      } on Object catch (e) {
        debugPrint('[TRACKING] Error during location update: $e');
        dev.log('[tracking] error: $e');
      }
    });
  }

  void _stopLocationUpdates() {
    debugPrint('[TRACKING] Stopping location updates');
    _updateTimer?.cancel();
    _updateTimer = null;
    _lastPosition = null;
  }
}
