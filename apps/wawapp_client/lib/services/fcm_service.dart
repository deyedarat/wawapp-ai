import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_installations/firebase_installations.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseInstallations _installations = FirebaseInstallations.instance;

  Future<void> initialize() async {
    try {
      await _messaging.requestPermission();
      final token = await _getTokenWithRetry();
      if (token != null) {
        await _saveToken(token);
      }
    } catch (e) {
      debugPrint('FCM initialization error: $e');
      if (e.toString().contains('FIS_AUTH_ERROR')) {
        await _handleFisAuthError();
      }
    }
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  Future<String?> _getTokenWithRetry() async {
    for (int i = 0; i < 3; i++) {
      try {
        final token = await _messaging.getToken();
        if (token != null) return token;
      } catch (e) {
        debugPrint('Token retrieval attempt ${i + 1} failed: $e');
        if (i == 2) rethrow;
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    return null;
  }

  Future<void> _handleFisAuthError() async {
    try {
      debugPrint('Handling FIS_AUTH_ERROR: deleting installation ID');
      await _installations.delete();
      await Future.delayed(const Duration(seconds: 2));
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
        debugPrint('FCM token recovered after FIS reset');
      }
    } catch (e) {
      debugPrint('FIS recovery failed: $e');
    }
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
