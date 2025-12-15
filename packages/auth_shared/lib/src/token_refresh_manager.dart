import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Manages Firebase Auth token refresh for Phase 2 (TC-02)
/// Ensures tokens are refreshed before expiry to avoid session interruptions
class TokenRefreshManager {
  final FirebaseAuth _firebaseAuth;
  Timer? _refreshTimer;
  DateTime? _lastRefreshTime;
  
  // Callback for logging/observability
  final Function(TokenRefreshEvent)? onRefreshEvent;

  TokenRefreshManager({
    required FirebaseAuth firebaseAuth,
    this.onRefreshEvent,
  }) : _firebaseAuth = firebaseAuth;

  /// Start monitoring and auto-refreshing tokens
  /// Tokens are refreshed 5 minutes before expiry (default Firebase token TTL is 1 hour)
  void startMonitoring() {
    // Cancel existing timer if any
    stopMonitoring();

    // Check immediately if token needs refresh
    _checkAndRefreshToken();

    // Schedule periodic checks every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkAndRefreshToken();
    });
  }

  /// Stop monitoring (call on logout or app dispose)
  void stopMonitoring() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Manually force token refresh (for testing or explicit refresh needs)
  Future<bool> forceRefresh() async {
    return await _refreshToken();
  }

  Future<void> _checkAndRefreshToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      stopMonitoring();
      return;
    }

    try {
      // Get current token with metadata
      final idTokenResult = await user.getIdTokenResult();
      final expirationTime = idTokenResult.expirationTime;

      if (expirationTime == null) {
        if (kDebugMode) print('[TokenRefresh] No expiration time found');
        return;
      }

      // Calculate time until expiration
      final now = DateTime.now();
      final timeUntilExpiry = expirationTime.difference(now);

      if (kDebugMode) {
        print('[TokenRefresh] Token expires in ${timeUntilExpiry.inMinutes} minutes');
      }

      // Refresh if less than 10 minutes until expiry
      if (timeUntilExpiry.inMinutes < 10) {
        await _refreshToken();
      }
    } catch (e) {
      if (kDebugMode) print('[TokenRefresh] Error checking token: $e');
      onRefreshEvent?.call(TokenRefreshEvent.checkFailed(e.toString()));
    }
  }

  Future<bool> _refreshToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;

    // Don't refresh if we just refreshed within last minute (avoid excessive refreshes)
    if (_lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh.inSeconds < 60) {
        if (kDebugMode) print('[TokenRefresh] Skipping refresh, refreshed ${timeSinceLastRefresh.inSeconds}s ago');
        return true;
      }
    }

    try {
      if (kDebugMode) print('[TokenRefresh] Attempting token refresh...');
      onRefreshEvent?.call(TokenRefreshEvent.attemptStarted());

      // Force refresh the ID token
      await user.getIdToken(true);
      
      _lastRefreshTime = DateTime.now();
      if (kDebugMode) print('[TokenRefresh] Token refreshed successfully');
      onRefreshEvent?.call(TokenRefreshEvent.success());
      
      return true;
    } catch (e) {
      if (kDebugMode) print('[TokenRefresh] Token refresh failed: $e');
      onRefreshEvent?.call(TokenRefreshEvent.failed(e.toString()));
      
      return false;
    }
  }

  /// Get time since last refresh (for debugging/testing)
  Duration? getTimeSinceLastRefresh() {
    if (_lastRefreshTime == null) return null;
    return DateTime.now().difference(_lastRefreshTime!);
  }

  /// Check if monitoring is active
  bool get isMonitoring => _refreshTimer != null && _refreshTimer!.isActive;
}

/// Token refresh event for observability integration
class TokenRefreshEvent {
  final TokenRefreshStatus status;
  final String? errorMessage;
  final DateTime timestamp;

  TokenRefreshEvent._({
    required this.status,
    this.errorMessage,
  }) : timestamp = DateTime.now();

  factory TokenRefreshEvent.attemptStarted() => TokenRefreshEvent._(
    status: TokenRefreshStatus.attemptStarted,
  );

  factory TokenRefreshEvent.success() => TokenRefreshEvent._(
    status: TokenRefreshStatus.success,
  );

  factory TokenRefreshEvent.failed(String error) => TokenRefreshEvent._(
    status: TokenRefreshStatus.failed,
    errorMessage: error,
  );

  factory TokenRefreshEvent.checkFailed(String error) => TokenRefreshEvent._(
    status: TokenRefreshStatus.checkFailed,
    errorMessage: error,
  );
}

enum TokenRefreshStatus {
  attemptStarted,
  success,
  failed,
  checkFailed,
}
