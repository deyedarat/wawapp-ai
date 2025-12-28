/**
 * FIX #4: Location Update Throttling Service
 * 
 * CRITICAL: Prevents excessive Firestore writes by throttling location updates:
 * - Max 1 write per 10 seconds
 * - Min distance threshold (25-50m)
 * - Ignores poor accuracy (>30m)
 * - Only when driver is online/active
 * 
 * This prevents:
 * - Firestore quota exhaustion
 * - Unnecessary battery drain
 * - Performance degradation
 * - Cost overruns
 * 
 * Author: WawApp Development Team (Critical Fix)
 * Last Updated: 2025-12-28
 */

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationThrottlingService {
  static final LocationThrottlingService instance = LocationThrottlingService._internal();
  factory LocationThrottlingService() => instance;
  LocationThrottlingService._internal();

  // Throttling configuration
  static const Duration _minUpdateInterval = Duration(seconds: 10);
  static const double _minDistanceMeters = 25.0; // Minimum distance to trigger update
  static const double _maxAccuracyMeters = 30.0; // Ignore readings with poor accuracy

  // State tracking
  DateTime? _lastUpdateTime;
  Position? _lastPosition;
  bool _isDriverOnline = false;

  /// Set driver online status (only update location when online)
  void setDriverOnlineStatus(bool isOnline) {
    _isDriverOnline = isOnline;
    if (kDebugMode) {
      debugPrint('[LocationThrottle] Driver online status: $isOnline');
    }
  }

  /// Check if location update should be sent to Firestore
  /// 
  /// Returns true if update should proceed, false if throttled
  bool shouldUpdateLocation(Position newPosition) {
    // Guard: Don't update if driver is offline
    if (!_isDriverOnline) {
      if (kDebugMode) {
        debugPrint('[LocationThrottle] Throttled: driver offline');
      }
      return false;
    }

    // Guard: Ignore poor accuracy readings
    if (newPosition.accuracy > _maxAccuracyMeters) {
      if (kDebugMode) {
        debugPrint('[LocationThrottle] Throttled: poor accuracy (${newPosition.accuracy.toStringAsFixed(1)}m)');
      }
      return false;
    }

    final now = DateTime.now();

    // Guard: Enforce minimum time interval
    if (_lastUpdateTime != null) {
      final timeSinceLastUpdate = now.difference(_lastUpdateTime!);
      if (timeSinceLastUpdate < _minUpdateInterval) {
        if (kDebugMode) {
          debugPrint('[LocationThrottle] Throttled: too soon (${timeSinceLastUpdate.inSeconds}s < ${_minUpdateInterval.inSeconds}s)');
        }
        return false;
      }
    }

    // Guard: Enforce minimum distance threshold
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      if (distance < _minDistanceMeters) {
        if (kDebugMode) {
          debugPrint('[LocationThrottle] Throttled: insufficient distance (${distance.toStringAsFixed(1)}m < $_minDistanceMeters m)');
        }
        return false;
      }
    }

    // All checks passed - allow update
    _lastUpdateTime = now;
    _lastPosition = newPosition;

    if (kDebugMode) {
      debugPrint('[LocationThrottle] ✓ Update allowed: accuracy=${newPosition.accuracy.toStringAsFixed(1)}m');
    }

    return true;
  }

  /// Update driver location in Firestore (with throttling)
  /// 
  /// Returns true if update was sent, false if throttled
  Future<bool> updateDriverLocation(Position position) async {
    if (!shouldUpdateLocation(position)) {
      return false; // Throttled
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('[LocationThrottle] Error: user not authenticated');
        }
        return false;
      }

      await FirebaseFirestore.instance
          .collection('driver_locations')
          .doc(user.uid)
          .set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('[LocationThrottle] ✓ Location updated successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationThrottle] Error updating location: $e');
      }
      return false;
    }
  }

  /// Reset throttling state (call on logout)
  void reset() {
    _lastUpdateTime = null;
    _lastPosition = null;
    _isDriverOnline = false;
    if (kDebugMode) {
      debugPrint('[LocationThrottle] State reset');
    }
  }
}
