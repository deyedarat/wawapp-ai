/**
 * Admin Drivers Service
 * Handles driver-related operations for admin panel
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
      if (kDebugMode) {
        print('Error fetching driver: $e');
      }
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
      if (kDebugMode) {
        print('Error blocking driver: $e');
      }
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
      if (kDebugMode) {
        print('Error unblocking driver: $e');
      }
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
      if (kDebugMode) {
        print('Error verifying driver: $e');
      }
      return false;
    }
  }

  /// Add balance to driver wallet
  Future<bool> addBalance(String driverId, int amount, {String? note}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final walletId = driverId;
      final walletRef = _firestore.collection('wallets').doc(walletId);

      await _firestore.runTransaction((transaction) async {
        final walletDoc = await transaction.get(walletRef);

        if (!walletDoc.exists) {
          // Create wallet if it doesn't exist
          transaction.set(walletRef, {
            'type': 'driver',
            'ownerId': driverId,
            'balance': amount,
            'totalCredited': amount,
            'totalDebited': 0,
            'pendingPayout': 0,
            'currency': 'MRU',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final data = walletDoc.data()!;
          final currentBalance = data['balance'] as int? ?? 0;
          final totalCredited = data['totalCredited'] as int? ?? 0;
          transaction.update(walletRef, {
            'balance': currentBalance + amount,
            'totalCredited': totalCredited + amount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Record transaction in top-level collection
        final txnRef = _firestore.collection('transactions').doc();
        transaction.set(txnRef, {
          'walletId': walletId,
          'type': 'credit',
          'source': 'manual_adjustment',
          'amount': amount,
          'currency': 'MRU',
          'adminId': user.uid,
          'note': note ?? 'إضافة رصيد بواسطة المسؤول',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding balance: $e');
      }
      return false;
    }
  }

  /// Unverify a driver
  Future<bool> unverifyDriver(String driverId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.collection('drivers').doc(driverId).update({
        'isVerified': false,
        'unverifiedAt': FieldValue.serverTimestamp(),
        'unverifiedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error unverifying driver: $e');
      }
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
      if (kDebugMode) {
        print('Error fetching driver stats: $e');
      }
      return {};
    }
  }
}
