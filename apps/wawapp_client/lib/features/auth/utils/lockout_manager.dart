import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_logger.dart';

class LockoutManager {
  final FirebaseFirestore _firestore;
  static const List<int> lockoutDurations = [60, 300, 900, 3600, 86400]; // seconds

  LockoutManager({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Duration?> getLockoutDuration(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutKey = 'lockout_$phoneNumber';
      final lockoutData = prefs.getString(lockoutKey);
      
      if (lockoutData == null) return null;
      
      final parts = lockoutData.split('|');
      if (parts.length != 3) return null;
      
      final lockedUntil = DateTime.parse(parts[0]);
      final failedAttempts = int.parse(parts[1]);
      final lockoutLevel = int.parse(parts[2]);
      
      if (DateTime.now().isBefore(lockedUntil)) {
        return lockedUntil.difference(DateTime.now());
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> recordFailedAttempt(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutKey = 'lockout_$phoneNumber';
      final lockoutData = prefs.getString(lockoutKey);
      
      int failedAttempts = 1;
      int lockoutLevel = 0;
      
      if (lockoutData != null) {
        final parts = lockoutData.split('|');
        if (parts.length == 3) {
          final lockedUntil = DateTime.parse(parts[0]);
          if (DateTime.now().isAfter(lockedUntil)) {
            failedAttempts = int.parse(parts[1]) + 1;
            lockoutLevel = int.parse(parts[2]);
          }
        }
      }

      if (failedAttempts >= 5) {
        if (lockoutLevel < lockoutDurations.length - 1) {
          lockoutLevel++;
        }
        
        final lockoutDuration = Duration(seconds: lockoutDurations[lockoutLevel]);
        final lockedUntil = DateTime.now().add(lockoutDuration);
        
        await prefs.setString(lockoutKey, '${lockedUntil.toIso8601String()}|$failedAttempts|$lockoutLevel');
        
        await AuthLogger.logLockoutTriggered(phoneNumber, lockoutDuration);
        
        // Update Firestore if user exists
        final usersQuery = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: phoneNumber)
            .limit(1)
            .get();
            
        if (usersQuery.docs.isNotEmpty) {
          await _firestore.collection('users').doc(usersQuery.docs.first.id).update({
            'lockoutInfo.failedAttempts': failedAttempts,
            'lockoutInfo.lockedUntil': Timestamp.fromDate(lockedUntil),
            'lockoutInfo.lockoutLevel': lockoutLevel,
          });
        }
      } else {
        await prefs.setString(lockoutKey, '${DateTime.now().toIso8601String()}|$failedAttempts|$lockoutLevel');
      }
    } catch (e) {
      // Silent fail for lockout tracking
    }
  }

  Future<void> clearLockout(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lockout_$phoneNumber');
      
      // Clear Firestore lockout info
      final usersQuery = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
          
      if (usersQuery.docs.isNotEmpty) {
        await _firestore.collection('users').doc(usersQuery.docs.first.id).update({
          'lockoutInfo.failedAttempts': 0,
          'lockoutInfo.lockedUntil': null,
          'lockoutInfo.lockoutLevel': 0,
        });
      }
    } catch (e) {
      // Silent fail for lockout clearing
    }
  }
}