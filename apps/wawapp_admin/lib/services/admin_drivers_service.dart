/**
 * Admin Drivers Service
 * Handles driver-related operations for admin panel
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart';

class AdminDriversService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get drivers stream
  Stream<List<DriverProfile>> getDriversStream({
    bool? onlineOnly,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('drivers')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (onlineOnly == true) {
      query = query.where('isOnline', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => DriverProfile.fromFirestore(doc))
          .toList();
    });
  }

  /// Get a single driver by ID
  Future<DriverProfile?> getDriverById(String driverId) async {
    try {
      final doc = await _firestore.collection('drivers').doc(driverId).get();
      if (!doc.exists) return null;
      return DriverProfile.fromFirestore(doc);
    } catch (e) {
      print('Error fetching driver: $e');
      return null;
    }
  }

  /// Block a driver
  Future<bool> blockDriver(String driverId, {String? reason}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.collection('drivers').doc(driverId).update({
        'isBlocked': true,
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': user.uid,
        'blockReason': reason ?? 'Blocked by admin',
        'isOnline': false, // Force offline when blocked
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error blocking driver: $e');
      return false;
    }
  }

  /// Unblock a driver
  Future<bool> unblockDriver(String driverId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.collection('drivers').doc(driverId).update({
        'isBlocked': false,
        'unblockedAt': FieldValue.serverTimestamp(),
        'unblockedBy': user.uid,
        'blockReason': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error unblocking driver: $e');
      return false;
    }
  }

  /// Verify a driver
  Future<bool> verifyDriver(String driverId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.collection('drivers').doc(driverId).update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error verifying driver: $e');
      return false;
    }
  }

  /// Get driver statistics
  Future<Map<String, int>> getDriverStats() async {
    try {
      final snapshot = await _firestore.collection('drivers').get();
      
      int totalDrivers = snapshot.size;
      int onlineDrivers = 0;
      int verifiedDrivers = 0;
      int blockedDrivers = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isOnline'] == true) onlineDrivers++;
        if (data['isVerified'] == true) verifiedDrivers++;
        if (data['isBlocked'] == true) blockedDrivers++;
      }

      return {
        'total': totalDrivers,
        'online': onlineDrivers,
        'verified': verifiedDrivers,
        'blocked': blockedDrivers,
      };
    } catch (e) {
      print('Error fetching driver stats: $e');
      return {};
    }
  }
}
