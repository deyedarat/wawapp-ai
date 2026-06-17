/**
 * Admin Drivers Service
 * Handles driver-related operations for admin panel
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:core_shared/core_shared.dart';
import 'audit_log_service.dart';

class AdminDriversService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuditLogService _auditLog = AuditLogService();

  /// Get drivers stream
  Stream<List<DriverProfile>> getDriversStream({bool? onlineOnly, int limit = 100}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('drivers')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (onlineOnly != null) {
      query = query.where('isOnline', isEqualTo: onlineOnly);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DriverProfile.fromFirestore(doc)).toList();
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

      await _auditLog.log(
        action: 'driver_blocked',
        category: 'driver',
        targetId: driverId,
        targetType: 'driver',
        details: {'reason': reason ?? 'Blocked by admin'},
      );

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

      await _auditLog.log(action: 'driver_unblocked', category: 'driver', targetId: driverId, targetType: 'driver');

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

      await _auditLog.log(action: 'driver_verified', category: 'driver', targetId: driverId, targetType: 'driver');

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

      await _auditLog.log(
        action: 'driver_balance_added',
        category: 'finance',
        targetId: driverId,
        targetType: 'driver',
        details: {'amount': amount, 'note': note},
      );

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

      await _auditLog.log(action: 'driver_unverified', category: 'driver', targetId: driverId, targetType: 'driver');

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error unverifying driver: $e');
      }
      return false;
    }
  }

  /// Get driver dispatch state (eligibility status)
  Future<Map<String, dynamic>?> getDriverDispatchState(String driverId) async {
    try {
      final doc = await _firestore.collection('driver_dispatch_state').doc(driverId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching dispatch state: $e');
      }
      return null;
    }
  }

  /// Get driver location status
  Future<Map<String, dynamic>?> getDriverLocationStatus(String driverId) async {
    try {
      final doc = await _firestore.collection('driver_locations').doc(driverId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching driver location: $e');
      }
      return null;
    }
  }

  /// Get full driver eligibility diagnosis
  Future<Map<String, dynamic>> getDriverEligibilityDiagnosis(String driverId) async {
    final results = <String, dynamic>{'eligible': true, 'reasons': <String>[]};

    // 1. Check driver profile
    final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
    if (!driverDoc.exists) {
      results['eligible'] = false;
      results['reasons'] = ['ملف السائق غير موجود'];
      return results;
    }
    final driverData = driverDoc.data()!;

    if (driverData['isOnline'] != true) {
      results['eligible'] = false;
      (results['reasons'] as List).add('غير متصل');
    }

    if (driverData['isVerified'] != true) {
      results['eligible'] = false;
      (results['reasons'] as List).add('غير موثّق');
    }

    if (driverData['isBlocked'] == true) {
      results['eligible'] = false;
      (results['reasons'] as List).add('محظور: ${driverData['blockReason'] ?? ''}');
    }

    // Profile completeness
    final missing = <String>[];
    if (driverData['name'] == null || (driverData['name'] as String).isEmpty) missing.add('الاسم');
    if (driverData['vehicleType'] == null || (driverData['vehicleType'] as String).isEmpty) missing.add('نوع المركبة');
    if (driverData['vehiclePlate'] == null || (driverData['vehiclePlate'] as String).isEmpty)
      missing.add('لوحة المركبة');
    if (driverData['city'] == null || (driverData['city'] as String).isEmpty) missing.add('المدينة');
    if (driverData['fcmToken'] == null || (driverData['fcmToken'] as String).isEmpty) missing.add('رمز الإشعارات');
    if (missing.isNotEmpty) {
      results['eligible'] = false;
      (results['reasons'] as List).add('ملف ناقص: ${missing.join("، ")}');
    }

    // 2. Check location
    final locationDoc = await _firestore.collection('driver_locations').doc(driverId).get();
    if (!locationDoc.exists) {
      results['eligible'] = false;
      (results['reasons'] as List).add('لا يوجد موقع مسجّل');
    } else {
      final locationData = locationDoc.data()!;
      final updatedAt = locationData['updatedAt'] as Timestamp?;
      if (updatedAt != null) {
        final age = DateTime.now().difference(updatedAt.toDate());
        results['locationAge'] = age.inMinutes;
        if (age.inMinutes > 30) {
          results['eligible'] = false;
          (results['reasons'] as List).add('الموقع قديم (${age.inMinutes} دقيقة)');
        }
      }
    }

    // 3. Check dispatch state
    final stateDoc = await _firestore.collection('driver_dispatch_state').doc(driverId).get();
    if (stateDoc.exists) {
      final stateData = stateDoc.data()!;
      results['dispatchState'] = stateData;

      if (stateData['activeOrderId'] != null) {
        results['eligible'] = false;
        (results['reasons'] as List).add('محجوب: طلب نشط (${stateData['activeOrderId']})');
      }
      if (stateData['status'] == 'busy') {
        results['eligible'] = false;
        (results['reasons'] as List).add('محجوب: حالة مشغول');
      }
      if (stateData['activeOfferId'] != null) {
        (results['reasons'] as List).add('لديه عرض نشط (${stateData['activeOfferId']})');
      }
    }

    return results;
  }

  /// Reset driver dispatch state (unblock from stuck state)
  Future<bool> resetDriverDispatchState(String driverId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final ref = _firestore.collection('driver_dispatch_state').doc(driverId);
      final doc = await ref.get();

      if (doc.exists) {
        await ref.update({
          'status': 'available',
          'activeOrderId': null,
          'activeOfferId': null,
          'acceptanceLock': false,
          'lockExpiresAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _auditLog.log(
        action: 'driver_dispatch_state_reset',
        category: 'driver',
        targetId: driverId,
        targetType: 'driver',
        details: {'resetBy': user.uid},
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting dispatch state: $e');
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

      return {'total': totalDrivers, 'online': onlineDrivers, 'verified': verifiedDrivers, 'blocked': blockedDrivers};
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching driver stats: $e');
      }
      return {};
    }
  }
}
