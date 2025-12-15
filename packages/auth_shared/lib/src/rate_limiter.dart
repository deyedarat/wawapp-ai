import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class RateLimiter {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // OTP rate limiting: max 3 requests per user per 10 minutes
  static Future<void> checkOtpRateLimit() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Must be authenticated to send OTP');
    }

    final uid = user.uid;
    final docRef = _db.collection('rate_limits_otp').doc(uid);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      final now = FieldValue.serverTimestamp();

      if (snap.exists) {
        final data = snap.data()!;
        final count = data['count'] as int? ?? 0;
        final windowStart = (data['windowStart'] as Timestamp?)?.toDate();

        if (windowStart != null) {
          final elapsed = DateTime.now().difference(windowStart);
          if (elapsed.inMinutes < 10) {
            if (count >= 3) {
              throw Exception('Too many OTP requests. Try again in ${10 - elapsed.inMinutes} minutes.');
            }
            transaction.update(docRef, {'count': count + 1, 'updatedAt': now});
            return;
          }
        }
      }

      // Start new window
      transaction.set(docRef, {
        'count': 1,
        'windowStart': now,
        'updatedAt': now,
      });
    });
  }

  // PIN rate limiting: max 5 attempts per user per 15 minutes
  static Future<void> checkPinRateLimit() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Must be authenticated to verify PIN');
    }

    final uid = user.uid;
    final docRef = _db.collection('rate_limits_pin').doc(uid);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      final now = FieldValue.serverTimestamp();

      if (snap.exists) {
        final data = snap.data()!;
        final count = data['count'] as int? ?? 0;
        final windowStart = (data['windowStart'] as Timestamp?)?.toDate();

        if (windowStart != null) {
          final elapsed = DateTime.now().difference(windowStart);
          if (elapsed.inMinutes < 15) {
            if (count >= 5) {
              throw Exception('Too many PIN attempts. Try again in ${15 - elapsed.inMinutes} minutes.');
            }
            transaction.update(docRef, {'count': count + 1, 'updatedAt': now});
            return;
          }
        }
      }

      // Start new window
      transaction.set(docRef, {
        'count': 1,
        'windowStart': now,
        'updatedAt': now,
      });
    });
  }

  // Optional: cleanup expired rate limit documents (can be called periodically)
  static Future<void> cleanupExpired() async {
    final cutoffOtp = DateTime.now().subtract(const Duration(minutes: 10));
    final cutoffPin = DateTime.now().subtract(const Duration(minutes: 15));

    try {
      final otpSnap = await _db
          .collection('rate_limits_otp')
          .where('windowStart', isLessThan: Timestamp.fromDate(cutoffOtp))
          .get();
      for (var doc in otpSnap.docs) {
        await doc.reference.delete();
      }

      final pinSnap = await _db
          .collection('rate_limits_pin')
          .where('windowStart', isLessThan: Timestamp.fromDate(cutoffPin))
          .get();
      for (var doc in pinSnap.docs) {
        await doc.reference.delete();
      }

      if (kDebugMode) {
        print('[RateLimiter] Cleanup: deleted ${otpSnap.docs.length} OTP + ${pinSnap.docs.length} PIN expired docs');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[RateLimiter] Cleanup error: $e');
      }
    }
  }
}
