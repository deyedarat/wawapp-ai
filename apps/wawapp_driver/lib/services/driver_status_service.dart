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

      // Log analytics event and update user property
      AnalyticsService.instance.logDriverWentOnline();
      AnalyticsService.instance.setUserProperties(
        userId: driverId,
        isOnline: true,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
            '[DriverStatus] Permission denied setting online. Check Firestore rules for /drivers/{uid}');
      }
      rethrow;
    } on Object catch (e) {
      debugPrint('[DriverStatus] Error setting online: $e');
      rethrow;
    }
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
      AnalyticsService.instance.setUserProperties(
        userId: driverId,
        isOnline: false,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
            '[DriverStatus] Permission denied setting offline. Check Firestore rules for /drivers/{uid}');
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

    debugPrint(
        '[DriverStatus] 👀 Watching online status for driver: $driverId');
    debugPrint('[DriverStatus] 📍 Firestore path: drivers/$driverId');

    return _firestore
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint(
            '[DriverStatus] ⚠️ Driver document does not exist: drivers/$driverId');
        debugPrint(
            '[DriverStatus] 💡 Create document by going ONLINE in the app');
        return false;
      }

      final data = snapshot.data();
      if (data == null) {
        debugPrint(
            '[DriverStatus] ⚠️ Driver document exists but has null data');
        return false;
      }

      final isOnline = data['isOnline'] as bool? ?? false;
      debugPrint(
          '[DriverStatus] 📡 Driver status changed: ${isOnline ? "🟢 ONLINE" : "🔴 OFFLINE"}');

      if (!isOnline) {
        debugPrint(
            '[DriverStatus] ℹ️ Driver is OFFLINE - nearby orders will be empty');
      }

      return isOnline;
    }).handleError((error) {
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
