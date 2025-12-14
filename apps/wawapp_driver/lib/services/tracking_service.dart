import 'dart:async';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import 'orders_service.dart';
import 'driver_status_service.dart';

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService.instance;
  final OrdersService _ordersService = OrdersService();

  StreamSubscription? _orderSubscription;
  StreamSubscription? _onlineStatusSubscription;
  Timer? _updateTimer;
  Position? _lastPosition;
  bool _isTracking = false;
  int _updateIntervalSeconds = 10; // Default 10 seconds
  int _consecutiveSmallMoves = 0;  // Track consecutive small movements
  int _positionUpdatesCount = 0;   // Count position updates for debugging
  DateTime? _firstFixTimestamp;    // Track first location fix timestamp

  static const String _logTag = '[TRACKING_SERVICE]';

  Future<void> startTracking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isTracking) {
      return;
    }

    await _loadRemoteConfig();
    debugPrint('[TRACKING] Starting tracking for driver: ${user.uid}');
    dev.log('[tracking] start');
    _isTracking = true;

    // NEW: Subscribe to online status changes - location updates whenever driver is online
    _onlineStatusSubscription =
        DriverStatusService.instance.watchOnlineStatus(user.uid).listen((isOnline) {
      debugPrint('[TRACKING] Online status changed: ${isOnline ? "ONLINE" : "OFFLINE"}');
      if (isOnline) {
        _startLocationUpdates(user.uid);
      } else {
        _stopLocationUpdates();
      }
    });

    // KEEP EXISTING: Subscribe to active orders for monitoring
    _orderSubscription =
        _ordersService.getDriverActiveOrders(user.uid).listen((orders) {
      debugPrint('[TRACKING] Active orders count: ${orders.length}');
      // When driver has active order, tracking is already running via online status
      // This subscription is kept for monitoring and future enhancements
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
    _onlineStatusSubscription?.cancel();
  }

  Future<void> _startLocationUpdates(String driverId) async {
    _updateTimer?.cancel();
    _positionUpdatesCount = 0;
    _firstFixTimestamp = null;

    debugPrint('$_logTag Starting location updates for driver: $driverId');

    // FIRST-FIX GUARANTEE: Get immediate location before starting stream
    try {
      debugPrint('$_logTag Obtaining first GPS fix...');
      final firstPosition = await _locationService.getCurrentPosition(
        timeout: const Duration(seconds: 20),
      );

      _firstFixTimestamp = DateTime.now();
      _positionUpdatesCount++;

      debugPrint('$_logTag ✅ First fix obtained in ${_firstFixTimestamp!.difference(DateTime.now()).inSeconds.abs()}s');
      debugPrint('$_logTag First position: lat=${firstPosition.latitude}, lng=${firstPosition.longitude}, accuracy=${firstPosition.accuracy}m');

      // Write first position immediately to Firestore
      await _writeLocationToFirestore(driverId, firstPosition);
      _lastPosition = firstPosition;

    } on TimeoutException catch (e) {
      debugPrint('$_logTag ❌ First fix timeout: $e');
      dev.log('[tracking] first-fix timeout: $e');
      throw Exception('Could not obtain GPS fix within 20 seconds. Please check GPS signal.');
    } on LocationServiceDisabledException {
      debugPrint('$_logTag ❌ GPS disabled during first fix');
      dev.log('[tracking] gps-disabled');
      throw Exception('GPS was disabled. Please enable location services.');
    } on Object catch (e) {
      debugPrint('$_logTag ❌ First fix error: $e');
      dev.log('[tracking] first-fix error: $e');
      throw Exception('Failed to get initial location: $e');
    }

    // Start position stream for continuous updates
    debugPrint('$_logTag Starting position stream for continuous updates...');
    _locationService.startPositionStream(
      onPosition: (Position position) {
        _positionUpdatesCount++;
        debugPrint('$_logTag Position update #$_positionUpdatesCount: lat=${position.latitude}, lng=${position.longitude}');

        // Check if significant movement occurred
        if (_lastPosition != null) {
          final distance = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          debugPrint('$_logTag Distance from last position: ${distance.toStringAsFixed(1)}m');

          if (distance < 20) {
            _consecutiveSmallMoves++;
            debugPrint('$_logTag Small movement detected ($_consecutiveSmallMoves consecutive)');

            // Skip write if barely moving
            if (_consecutiveSmallMoves > 3) {
              debugPrint('$_logTag Skipping write due to minimal movement');
              return;
            }
          } else {
            _consecutiveSmallMoves = 0; // Reset on significant movement
          }
        }

        // Write to Firestore
        _writeLocationToFirestore(driverId, position).then((_) {
          _lastPosition = position;
        }).catchError((Object error) {
          debugPrint('$_logTag ❌ Error writing location: $error');
          dev.log('[tracking] write-error: $error');
        });
      },
      onError: (Object error) {
        debugPrint('$_logTag ❌ Position stream error: $error');
        dev.log('[tracking] stream-error: $error');
        // Stream errors are handled but don't stop tracking
        // User will be notified through the error callback
      },
    );

    // Also start periodic timer as backup (every 30 seconds)
    _updateTimer = Timer.periodic(Duration(seconds: _updateIntervalSeconds * 3), (_) async {
      debugPrint('$_logTag Periodic backup update (updates count: $_positionUpdatesCount)');

      // If stream hasn't provided updates recently, force a getCurrentPosition
      if (_lastPosition == null || DateTime.now().difference(_firstFixTimestamp!).inSeconds > 60) {
        try {
          final position = await _locationService.getCurrentPosition();
          await _writeLocationToFirestore(driverId, position);
          _lastPosition = position;
          _positionUpdatesCount++;
        } on Object catch (e) {
          debugPrint('$_logTag ❌ Periodic update error: $e');
          dev.log('[tracking] periodic-error: $e');
        }
      }
    });

    debugPrint('$_logTag Location tracking fully started for driver: $driverId');
  }

  /// Write location to Firestore with comprehensive logging
  Future<void> _writeLocationToFirestore(String driverId, Position position) async {
    final writeStartTime = DateTime.now();

    try {
      debugPrint('$_logTag Writing to Firestore: driver_locations/$driverId');
      debugPrint('$_logTag Position: lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m');

      await _firestore.collection('driver_locations').doc(driverId).set({
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final writeDuration = DateTime.now().difference(writeStartTime).inMilliseconds;

      debugPrint('$_logTag ✅ Firestore write successful (${writeDuration}ms)');
      debugPrint('$_logTag Path: driver_locations/$driverId');
      debugPrint('$_logTag Data: lat=${position.latitude}, lng=${position.longitude}, updatedAt=SERVER_TIMESTAMP');

      dev.log('[tracking] firestore-write lat=${position.latitude} lng=${position.longitude} accuracy=${position.accuracy}m duration=${writeDuration}ms');

    } on FirebaseException catch (e) {
      debugPrint('$_logTag ❌ Firestore write failed: ${e.code} - ${e.message}');
      dev.log('[tracking] firestore-error: ${e.code}');

      if (e.code == 'permission-denied') {
        debugPrint('$_logTag ⚠️ Permission denied writing to driver_locations/$driverId');
        debugPrint('$_logTag Check Firestore security rules');
      }

      rethrow;
    } on Object catch (e) {
      debugPrint('$_logTag ❌ Unexpected error writing to Firestore: $e');
      dev.log('[tracking] write-error: $e');
      rethrow;
    }
  }

  void _stopLocationUpdates() {
    debugPrint('$_logTag Stopping location updates');
    _updateTimer?.cancel();
    _updateTimer = null;
    _lastPosition = null;
    _positionUpdatesCount = 0;
    _firstFixTimestamp = null;
    _consecutiveSmallMoves = 0;

    // Stop position stream
    _locationService.stopPositionStream();

    debugPrint('$_logTag Location updates stopped');
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
      if (_updateIntervalSeconds < 5) {
        _updateIntervalSeconds = 5; // Min 5 seconds
      }
      if (_updateIntervalSeconds > 60) {
        _updateIntervalSeconds = 60; // Max 60 seconds
      }
    } on Object catch (e) {
      debugPrint('$_logTag Failed to load remote config, using default: $e');
      _updateIntervalSeconds = 10; // Fallback
    }
  }
}
