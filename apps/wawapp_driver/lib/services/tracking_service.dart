import 'dart:async';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
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
  int _updateIntervalSeconds = 10; // Default 10 seconds
  int _consecutiveSmallMoves = 0;  // Track consecutive small movements

  Future<void> startTracking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isTracking) {
      return;
    }

    await _loadRemoteConfig();
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
    _updateTimer = Timer.periodic(Duration(seconds: _updateIntervalSeconds), (_) async {
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
            _consecutiveSmallMoves++;
            
            // Exponential backoff: if driver barely moving, reduce write frequency
            if (_consecutiveSmallMoves > 3) {
              await Future.delayed(Duration(seconds: _updateIntervalSeconds * 2));
              _consecutiveSmallMoves = 0; // Reset after backoff
            }
            return; // Skip write
          } else {
            _consecutiveSmallMoves = 0; // Reset on significant movement
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

  Future<void> _loadRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();
      
      _updateIntervalSeconds = remoteConfig.getInt('location_update_interval_sec');
      if (_updateIntervalSeconds < 5) _updateIntervalSeconds = 5; // Min 5 seconds
      if (_updateIntervalSeconds > 60) _updateIntervalSeconds = 60; // Max 60 seconds
    } catch (e) {
      print('Failed to load remote config, using default: $e');
      _updateIntervalSeconds = 10; // Fallback
    }
  }
}
