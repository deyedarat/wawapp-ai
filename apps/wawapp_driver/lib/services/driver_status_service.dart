import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';

/// Service to manage driver online/offline status in Firestore
class DriverStatusService {
  DriverStatusService._();
  static final DriverStatusService instance = DriverStatusService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Set driver status to online
  /// Writes to drivers/{driverId}.isOnline = true
  /// Also seeds driver_locations with last known position as fallback
  /// (ensures driver is visible to dispatch even if GPS fix is delayed)
  Future<void> setOnline(String driverId) async {
    if (driverId.isEmpty) {
      throw ArgumentError('driverId cannot be empty');
    }

    try {
      await _firestore.collection('drivers').doc(driverId).set({
        'isOnline': true,
        'lastOnlineAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[DriverStatus] Driver $driverId is now ONLINE');

      // Seed driver_locations with last known position from driver doc.
      // This ensures the driver_locations document exists immediately,
      // even if the GPS first-fix takes time or Flutter engine disconnects
      // before the tracking service writes the first position.
      _seedLocationFromDriverDoc(driverId);

      // Log analytics event and update user property
      AnalyticsService.instance.logDriverWentOnline();
      AnalyticsService.instance.setUserProperties(userId: driverId, isOnline: true);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('[DriverStatus] Permission denied setting online. Check Firestore rules for /drivers/{uid}');
      }
      rethrow;
    } on Object catch (e) {
      debugPrint('[DriverStatus] Error setting online: $e');
      rethrow;
    }
  }

  /// Seeds driver_locations/{driverId} with the last known location from
  /// the driver profile. This is a best-effort fallback — if the document
  /// already exists with fresh data, the real tracking service will overwrite
  /// it with accurate GPS coordinates shortly after.
  void _seedLocationFromDriverDoc(String driverId) {
    // Fire-and-forget: don't block setOnline on this read+write
    _firestore
        .collection('drivers')
        .doc(driverId)
        .get()
        .then((doc) {
          if (!doc.exists) return;
          final data = doc.data();
          if (data == null) return;

          final location = data['location'];
          if (location == null) return;

          // location is a GeoPoint
          final double lat;
          final double lng;
          if (location is GeoPoint) {
            lat = location.latitude;
            lng = location.longitude;
          } else {
            return; // Unknown format
          }

          // Only seed if coordinates are valid (not 0,0)
          if (lat == 0.0 && lng == 0.0) return;

          _firestore
              .collection('driver_locations')
              .doc(driverId)
              .set({
                'lat': lat,
                'lng': lng,
                'accuracy': 100.0, // Mark as low-accuracy seed
                'heading': 0.0,
                'speed': 0.0,
                'updatedAt': FieldValue.serverTimestamp(),
                'seeded': true, // Flag so tracking service knows to overwrite
              })
              .then((_) {
                debugPrint('[DriverStatus] ✅ Seeded driver_locations/$driverId with last known position');
              })
              .catchError((Object e) {
                debugPrint('[DriverStatus] ⚠️ Failed to seed driver_locations: $e');
              });
        })
        .catchError((Object e) {
          debugPrint('[DriverStatus] ⚠️ Failed to read driver doc for location seed: $e');
        });
  }

  /// Set driver status to offline
  /// Writes to drivers/{driverId}.isOnline = false
  Future<void> setOffline(String driverId) async {
    if (driverId.isEmpty) {
      throw ArgumentError('driverId cannot be empty');
    }

    try {
      await _firestore.collection('drivers').doc(driverId).set({
        'isOnline': false,
        'lastOfflineAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[DriverStatus] Driver $driverId is now OFFLINE');

      // Log analytics event and update user property
      AnalyticsService.instance.logDriverWentOffline();
      AnalyticsService.instance.setUserProperties(userId: driverId, isOnline: false);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('[DriverStatus] Permission denied setting offline. Check Firestore rules for /drivers/{uid}');
      }
      rethrow;
    } on Object catch (e) {
      debugPrint('[DriverStatus] Error setting offline: $e');
      rethrow;
    }
  }

  /// Watch driver's online status from Firestore
  /// Returns a stream that emits true when online, false when offline
  Stream<bool> watchOnlineStatus(String driverId) {
    if (driverId.isEmpty) {
      debugPrint('[DriverStatus] ❌ watchOnlineStatus: driverId is empty');
      return Stream.value(false);
    }

    debugPrint('[DriverStatus] 👀 Watching online status for driver: $driverId');
    debugPrint('[DriverStatus] 📍 Firestore path: drivers/$driverId');

    return _firestore
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            debugPrint('[DriverStatus] ⚠️ Driver document does not exist: drivers/$driverId');
            debugPrint('[DriverStatus] 💡 Create document by going ONLINE in the app');
            return false;
          }

          final data = snapshot.data();
          if (data == null) {
            debugPrint('[DriverStatus] ⚠️ Driver document exists but has null data');
            return false;
          }

          final isOnline = data['isOnline'] as bool? ?? false;
          debugPrint('[DriverStatus] 📡 Driver status changed: ${isOnline ? "🟢 ONLINE" : "🔴 OFFLINE"}');

          if (!isOnline) {
            debugPrint('[DriverStatus] ℹ️ Driver is OFFLINE - nearby orders will be empty');
          }

          return isOnline;
        })
        .distinct()
        .handleError((error) {
          debugPrint('[DriverStatus] ❌ Error watching online status: $error');
          return false;
        });
  }

  /// Get current online status (one-time read)
  Future<bool> getOnlineStatus(String driverId) async {
    if (driverId.isEmpty) return false;

    try {
      final doc = await _firestore.collection('drivers').doc(driverId).get();

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      return data['isOnline'] as bool? ?? false;
    } on Object catch (e) {
      debugPrint('[DriverStatus] Error reading online status: $e');
      return false;
    }
  }
}
