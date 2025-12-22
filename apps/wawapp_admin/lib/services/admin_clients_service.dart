/**
 * Admin Clients Service
 * Handles client-related operations for admin panel
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:core_shared/core_shared.dart';

class AdminClientsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get clients stream
  Stream<List<ClientProfile>> getClientsStream({
    bool? verifiedOnly,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('clients')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (verifiedOnly == true) {
      query = query.where('isVerified', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ClientProfile.fromFirestore(doc))
          .toList();
    });
  }

  /// Get a single client by ID
  Future<ClientProfile?> getClientById(String clientId) async {
    try {
      final doc = await _firestore.collection('clients').doc(clientId).get();
      if (!doc.exists) return null;
      return ClientProfile.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching client: $e');
      }
      return null;
    }
  }

  /// Set client verification status
  Future<bool> setClientVerification(String clientId, bool isVerified) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final updateData = <String, dynamic>{
        'isVerified': isVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isVerified) {
        updateData['verifiedAt'] = FieldValue.serverTimestamp();
        updateData['verifiedBy'] = user.uid;
      } else {
        updateData['verifiedAt'] = FieldValue.delete();
        updateData['verifiedBy'] = FieldValue.delete();
      }

      await _firestore.collection('clients').doc(clientId).update(updateData);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error setting client verification: $e');
      }
      return false;
    }
  }

  /// Block a client
  Future<bool> blockClient(String clientId, {String? reason}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.collection('clients').doc(clientId).update({
        'isBlocked': true,
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': user.uid,
        'blockReason': reason ?? 'Blocked by admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error blocking client: $e');
      }
      return false;
    }
  }

  /// Unblock a client
  Future<bool> unblockClient(String clientId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.collection('clients').doc(clientId).update({
        'isBlocked': false,
        'unblockedAt': FieldValue.serverTimestamp(),
        'unblockedBy': user.uid,
        'blockReason': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error unblocking client: $e');
      }
      return false;
    }
  }

  /// Get client statistics
  Future<Map<String, int>> getClientStats() async {
    try {
      final snapshot = await _firestore.collection('clients').get();

      int totalClients = snapshot.size;
      int verifiedClients = 0;
      int blockedClients = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isVerified'] == true) verifiedClients++;
        if (data['isBlocked'] == true) blockedClients++;
      }

      return {
        'total': totalClients,
        'verified': verifiedClients,
        'blocked': blockedClients,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching client stats: $e');
      }
      return {};
    }
  }
}
