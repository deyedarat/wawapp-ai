import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/user_entity.dart';
import '../data/models/user_model.dart';

class LockoutManager {
  static const List<int> lockoutDurations = [60, 300, 900, 3600, 86400]; // seconds
  static const int maxFailedAttempts = 5;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Duration?> getLockoutDuration(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      
      final user = UserModel.fromFirestore(doc);
      if (!user.lockoutInfo.isLocked) return null;
      
      final now = DateTime.now();
      final lockedUntil = user.lockoutInfo.lockedUntil!;
      
      if (now.isBefore(lockedUntil)) {
        return lockedUntil.difference(now);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> recordFailedAttempt(String userId) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return;
        
        final user = UserModel.fromFirestore(doc);
        final currentAttempts = user.lockoutInfo.failedAttempts + 1;
        
        LockoutInfoModel newLockoutInfo;
        
        if (currentAttempts >= maxFailedAttempts) {
          final lockoutLevel = (user.lockoutInfo.lockoutLevel + 1).clamp(0, lockoutDurations.length - 1);
          final lockoutDuration = lockoutDurations[lockoutLevel];
          final lockedUntil = DateTime.now().add(Duration(seconds: lockoutDuration));
          
          newLockoutInfo = LockoutInfoModel(
            failedAttempts: currentAttempts,
            lockedUntil: lockedUntil,
            lockoutLevel: lockoutLevel,
          );
        } else {
          newLockoutInfo = LockoutInfoModel(
            failedAttempts: currentAttempts,
            lockedUntil: user.lockoutInfo.lockedUntil,
            lockoutLevel: user.lockoutInfo.lockoutLevel,
          );
        }
        
        transaction.update(docRef, {'lockoutInfo': newLockoutInfo.toMap()});
      });
    } catch (e) {
      // Log error
    }
  }

  Future<void> clearLockout(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lockoutInfo': const LockoutInfoModel(
          failedAttempts: 0,
          lockoutLevel: 0,
        ).toMap(),
      });
    } catch (e) {
      // Log error
    }
  }
}