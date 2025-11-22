import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:core_shared/core_shared.dart';

class DriverProfileRepository {
  final FirebaseFirestore _firestore;

  DriverProfileRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  Stream<DriverProfile?> watchProfile(String driverId) {
    debugPrint('[DriverProfile] Watching profile for driverId: $driverId');
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint('[DriverProfile] Profile not found for driverId: $driverId');
        return null;
      }
      return DriverProfile.fromFirestore(snapshot);
    });
  }

  Future<DriverProfile?> getProfile(String driverId) async {
    debugPrint('[DriverProfile] Fetching profile for driverId: $driverId');
    final snapshot = await _firestore.collection('drivers').doc(driverId).get();
    if (!snapshot.exists) {
      debugPrint('[DriverProfile] Profile not found for driverId: $driverId');
      return null;
    }
    return DriverProfile.fromFirestore(snapshot);
  }

  Future<void> createProfile(DriverProfile profile) async {
    debugPrint('[DriverProfile] Creating profile for driverId: ${profile.id}');
    await _firestore.collection('drivers').doc(profile.id).set(profile.toJson());
    debugPrint('[DriverProfile] Profile created successfully');
  }

  Future<void> updateProfile(DriverProfile profile) async {
    debugPrint('[DriverProfile] Updating profile for driverId: ${profile.id}');
    await _firestore
        .collection('drivers')
        .doc(profile.id)
        .update(profile.toDriverUpdateJson());
    debugPrint('[DriverProfile] Profile updated successfully');
  }

  Future<void> updatePhotoUrl(String driverId, String photoUrl) async {
    debugPrint('[DriverProfile] Updating photoUrl for driverId: $driverId');
    await _firestore.collection('drivers').doc(driverId).update({
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[DriverProfile] PhotoUrl updated successfully');
  }
}
