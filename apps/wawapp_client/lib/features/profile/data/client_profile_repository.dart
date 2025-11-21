import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:core_shared/core_shared.dart';
import '../../../services/analytics_service.dart';

class ClientProfileRepository {
  final FirebaseFirestore _firestore;

  ClientProfileRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  Stream<ClientProfile?> watchProfile(String userId) {
    debugPrint('[ClientProfile] Watching profile for userId: $userId');
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint('[ClientProfile] Profile not found for userId: $userId');
        return null;
      }
      return ClientProfile.fromFirestore(snapshot);
    });
  }

  Future<ClientProfile?> getProfile(String userId) async {
    debugPrint('[ClientProfile] Fetching profile for userId: $userId');
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) {
      debugPrint('[ClientProfile] Profile not found for userId: $userId');
      return null;
    }
    return ClientProfile.fromFirestore(snapshot);
  }

  Future<void> createProfile(ClientProfile profile) async {
    debugPrint('[ClientProfile] Creating profile for userId: ${profile.id}');
    await _firestore.collection('users').doc(profile.id).set(profile.toJson());
    debugPrint('[ClientProfile] Profile created successfully');
  }

  Future<void> updateProfile(ClientProfile profile) async {
    debugPrint('[ClientProfile] Updating profile for userId: ${profile.id}');
    await _firestore
        .collection('users')
        .doc(profile.id)
        .update(profile.toClientUpdateJson());
    debugPrint('[ClientProfile] Profile updated successfully');
  }

  Future<void> updatePhotoUrl(String userId, String photoUrl) async {
    debugPrint('[ClientProfile] Updating photoUrl for userId: $userId');
    await _firestore.collection('users').doc(userId).update({
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[ClientProfile] PhotoUrl updated successfully');
  }

  Stream<List<SavedLocation>> watchSavedLocations(String userId) {
    debugPrint('[SavedLocations] Watching saved locations for userId: $userId');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('savedLocations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SavedLocation.fromFirestore(doc))
          .toList();
    });
  }

  Future<List<SavedLocation>> getSavedLocations(String userId) async {
    debugPrint('[SavedLocations] Fetching saved locations for userId: $userId');
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('savedLocations')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => SavedLocation.fromFirestore(doc))
        .toList();
  }

  Future<void> addSavedLocation(String userId, SavedLocation location) async {
    debugPrint('[SavedLocations] Adding saved location for userId: $userId');
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('savedLocations')
        .doc(location.id)
        .set(location.toJson());
    debugPrint('[SavedLocations] Saved location added successfully');
    
    // Log analytics event
    AnalyticsService.instance.logSavedLocationAdded(
      locationLabel: location.label,
    );
  }

  Future<void> updateSavedLocation(String userId, SavedLocation location) async {
    debugPrint('[SavedLocations] Updating saved location for userId: $userId');
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('savedLocations')
        .doc(location.id)
        .update(location.toJson());
    debugPrint('[SavedLocations] Saved location updated successfully');
  }

  Future<void> deleteSavedLocation(String userId, String locationId) async {
    debugPrint('[SavedLocations] Deleting saved location for userId: $userId');
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('savedLocations')
        .doc(locationId)
        .delete();
    debugPrint('[SavedLocations] Saved location deleted successfully');
    
    // Log analytics event
    AnalyticsService.instance.logSavedLocationDeleted(
      locationId: locationId,
    );
  }
}