import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    await _messaging.requestPermission();
    await _tryGetAndSaveToken();
    _messaging.onTokenRefresh.listen((token) async {
      try {
        await _saveToken(token);
        debugPrint('[FCM] token refreshed and saved');
      } catch (e) {
        debugPrint('[FCM] saveToken on refresh failed: $e');
      }
    });
  }

  Future<void> _tryGetAndSaveToken() async {
    const delays = [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 6)
    ];
    for (int i = 0; i < delays.length; i++) {
      try {
        final token = await _messaging.getToken();
        if (token != null) {
          await _saveToken(token);
          return;
        }
      } catch (e) {
        debugPrint('[FCM] getToken attempt ${i + 1} failed: $e');
        try {
          await _messaging.deleteToken();
        } catch (_) {}
      }
      await Future.delayed(delays[i]);
    }
    debugPrint('[FCM] getToken deferred; will rely on onTokenRefresh');
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No authenticated user, skipping token save');
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmTokens': {token: true},
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('FCM token saved for user ${user.uid}: $token');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
}
