import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages a local acceptance lock to prevent race conditions when accepting orders.
///
/// **Problem**: When a driver accepts an order, there's a 1-3 second window where:
/// 1. The server hasn't updated Firestore yet (acceptOrder call in progress)
/// 2. Another order notification arrives via FCM
/// 3. The app checks Firestore and thinks the driver is still available
/// 4. Result: Driver sees two order notifications at the same time!
///
/// **Solution**: Use local state (SharedPreferences) to immediately mark the driver
/// as "busy" when they tap "Accept", before waiting for the server response.
/// This lock prevents new order notifications from appearing for 5 seconds.
class AcceptanceLockManager {
  static const _keyLastAcceptance = 'last_acceptance_timestamp';
  static const _keyLastOrderId = 'last_accepted_order_id';
  static const _lockWindowSeconds = 5; // Protection window: 5 seconds

  /// Record an order acceptance attempt.
  /// Called immediately when driver taps "Accept" button, before server call.
  static Future<void> setAcceptanceLock(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    await prefs.setInt(_keyLastAcceptance, now);
    await prefs.setString(_keyLastOrderId, orderId);

    if (kDebugMode) {
      dev.log('[AcceptanceLock] 🔒 Lock set for order: $orderId at $now');
    }
  }

  /// Check if we're within the acceptance window.
  /// Returns true if an order was accepted in the last 5 seconds.
  static Future<bool> isWithinAcceptanceWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAcceptanceMs = prefs.getInt(_keyLastAcceptance) ?? 0;

    if (lastAcceptanceMs == 0) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = now - lastAcceptanceMs;
    final isLocked = elapsedMs < (_lockWindowSeconds * 1000);

    if (kDebugMode && isLocked) {
      final remainingMs = (_lockWindowSeconds * 1000) - elapsedMs;
      dev.log('[AcceptanceLock] ⏳ Still locked (${remainingMs}ms remaining)');
    }

    return isLocked;
  }

  /// Clear the acceptance lock.
  /// Called when:
  /// - Order acceptance succeeds (after 5 second delay)
  /// - Order acceptance fails (immediately)
  static Future<void> clearLock() async {
    final prefs = await SharedPreferences.getInstance();
    final orderId = prefs.getString(_keyLastOrderId);

    await prefs.remove(_keyLastAcceptance);
    await prefs.remove(_keyLastOrderId);

    if (kDebugMode) {
      dev.log('[AcceptanceLock] 🔓 Lock cleared for order: $orderId');
    }
  }

  /// Get the last accepted order ID (for debugging).
  static Future<String?> getLastAcceptedOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastOrderId);
  }
}
