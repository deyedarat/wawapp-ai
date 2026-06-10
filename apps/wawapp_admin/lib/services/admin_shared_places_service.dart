/// Admin Shared Places Service
/// Handles CRUD operations for shared places (admin-managed locations visible to all users)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminSharedPlacesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collection = 'shared_places';

  /// Get all shared places as a stream
  Stream<List<SharedPlace>> getSharedPlacesStream({bool? activeOnly}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);

    if (activeOnly == true) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SharedPlace.fromFirestore(doc)).toList();
    });
  }

  /// Create a new shared place
  Future<String?> createSharedPlace({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? category,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final docRef = await _firestore.collection(_collection).add({
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'isActive': true,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating shared place: $e');
      }
      return null;
    }
  }

  /// Update an existing shared place
  Future<bool> updateSharedPlace({
    required String placeId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? category,
    bool? isActive,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final updateData = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};

      if (name != null) updateData['name'] = name;
      if (address != null) updateData['address'] = address;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (category != null) updateData['category'] = category;
      if (isActive != null) updateData['isActive'] = isActive;

      await _firestore.collection(_collection).doc(placeId).update(updateData);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating shared place: $e');
      }
      return false;
    }
  }

  /// Delete a shared place
  Future<bool> deleteSharedPlace(String placeId) async {
    try {
      await _firestore.collection(_collection).doc(placeId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting shared place: $e');
      }
      return false;
    }
  }

  /// Get shared places statistics
  Future<Map<String, int>> getSharedPlacesStats() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();

      int total = snapshot.size;
      int active = 0;
      int inactive = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isActive'] == true) {
          active++;
        } else {
          inactive++;
        }
      }

      return {'total': total, 'active': active, 'inactive': inactive};
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching shared places stats: $e');
      }
      return {};
    }
  }
}
