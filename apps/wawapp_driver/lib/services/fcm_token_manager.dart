import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages FCM token lifecycle with automatic refresh and Firestore sync.
///
/// Ensures the backend always has the latest token by:
/// - Listening to token refresh events
/// - Persisting token locally
/// - Syncing to Firestore on every change
/// - Validating token on app startup
class FcmTokenManager {
  static final FcmTokenManager _instance = FcmTokenManager._internal();
  factory FcmTokenManager() => _instance;
  FcmTokenManager._internal();

  static const String _kTokenKey = 'fcm_token';
  static const String _kTokenTimestampKey = 'fcm_token_timestamp';
  static const String _kDriversCollection = 'drivers';

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentToken;

  /// Initialize token manager and start listening for token changes.
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('[FcmTokenManager] 🚀 Initializing...');
    }

    // Get initial token
    await _refreshToken();

    // Listen for token refresh
    _tokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(
      _onTokenRefresh,
      onError: (error) {
        if (kDebugMode) {
          debugPrint('[FcmTokenManager] ❌ Token refresh error: $error');
        }
      },
    );

    if (kDebugMode) {
      debugPrint('[FcmTokenManager] ✅ Initialized successfully');
    }
  }

  /// Handle token refresh events.
  Future<void> _onTokenRefresh(String newToken) async {
    if (kDebugMode) {
      debugPrint(
          '[FcmTokenManager] 🔄 Token refreshed: ${_maskToken(newToken)}');
    }

    _currentToken = newToken;

    // Save locally
    await _saveTokenLocally(newToken);

    // Sync to Firestore
    await _syncTokenToFirestore(newToken);
  }

  /// Manually refresh token (call on app startup).
  Future<void> _refreshToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        if (kDebugMode) {
          debugPrint('[FcmTokenManager] ⚠️ Token is null');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('[FcmTokenManager] 📥 Got token: ${_maskToken(token)}');
      }

      _currentToken = token;

      // Check if token changed
      final lastToken = await _getLocalToken();
      if (lastToken != token) {
        if (kDebugMode) {
          debugPrint(
              '[FcmTokenManager] 🔄 Token changed, syncing to Firestore');
        }
        await _saveTokenLocally(token);
        await _syncTokenToFirestore(token);
      } else {
        if (kDebugMode) {
          debugPrint('[FcmTokenManager] ✅ Token unchanged');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmTokenManager] ❌ Error refreshing token: $e');
      }
    }
  }

  /// Save token to local storage (SharedPreferences).
  Future<void> _saveTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await prefs.setInt(
          _kTokenTimestampKey, DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode) {
        debugPrint('[FcmTokenManager] 💾 Token saved locally');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmTokenManager] ❌ Error saving token locally: $e');
      }
    }
  }

  /// Get token from local storage.
  Future<String?> _getLocalToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kTokenKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmTokenManager] ❌ Error getting local token: $e');
      }
      return null;
    }
  }

  /// Sync token to Firestore (driver document).
  Future<void> _syncTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint(
            '[FcmTokenManager] ⚠️ No user logged in, skipping Firestore sync');
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection(_kDriversCollection)
          .doc(user.uid)
          .set(
        {
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform.name,
        },
        SetOptions(merge: true),
      );

      if (kDebugMode) {
        debugPrint('[FcmTokenManager] ☁️ Token synced to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmTokenManager] ❌ Error syncing token to Firestore: $e');
      }
    }
  }

  /// Force token refresh (call after login).
  Future<void> forceRefresh() async {
    if (kDebugMode) {
      debugPrint('[FcmTokenManager] 🔄 Force refresh requested');
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
      await _refreshToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmTokenManager] ❌ Force refresh failed: $e');
      }
    }
  }

  /// Get current token.
  String? get currentToken => _currentToken;

  /// Check if token is valid (less than 60 days old).
  Future<bool> isTokenValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_kTokenTimestampKey);
      if (timestamp == null) return false;

      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      const maxAge = 60 * 24 * 60 * 60 * 1000; // 60 days in milliseconds

      return age < maxAge;
    } catch (e) {
      return false;
    }
  }

  /// Mask token for logging (show first 8 and last 8 characters).
  String _maskToken(String token) {
    if (token.length <= 16) return token;
    return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
  }

  /// Dispose resources.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
  }
}
