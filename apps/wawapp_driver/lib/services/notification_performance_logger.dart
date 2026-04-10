import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

/// Lightweight local-only performance logger for notification processing.
///
/// This logger tracks notification latency (time from FCM receive to display)
/// and rejection reasons (e.g., race condition, stale notification).
///
/// **Key features**:
/// - Local-only (no Firestore writes) - zero cost, zero latency impact
/// - Debug mode only - no production overhead
/// - Automatic cleanup - prevents memory leaks
///
/// **Usage**:
/// ```dart
/// // In background handler:
/// NotificationPerformanceLogger.markReceived(orderId);
///
/// // After showing notification:
/// NotificationPerformanceLogger.markShown(orderId);
///
/// // If rejected (race condition, etc):
/// NotificationPerformanceLogger.markRejected(orderId, 'acceptance_window');
/// ```
class NotificationPerformanceLogger {
  static final _timestamps = <String, int>{};

  /// Mark the start of notification processing.
  /// Called when FCM message is received in background handler.
  static void markReceived(String orderId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _timestamps['${orderId}_received'] = now;

    if (kDebugMode) {
      dev.log('[NotifPerf] 📩 Received: $orderId at $now');
    }
  }

  /// Mark notification shown to user.
  /// Called after successfully displaying the notification.
  static void markShown(String orderId) {
    final receivedMs = _timestamps['${orderId}_received'];
    if (receivedMs == null) {
      // markReceived wasn't called - unexpected
      if (kDebugMode) {
        dev.log('[NotifPerf] ⚠️  Shown: $orderId (no received timestamp - skipped markReceived?)');
      }
      return;
    }

    final shownMs = DateTime.now().millisecondsSinceEpoch;
    final latencyMs = shownMs - receivedMs;

    if (kDebugMode) {
      dev.log('[NotifPerf] 🔔 Shown: $orderId | Latency: ${latencyMs}ms');

      // Highlight performance issues
      if (latencyMs > 1000) {
        dev.log('[NotifPerf] ⚠️  HIGH LATENCY for $orderId: ${latencyMs}ms (target: <800ms)');
      } else if (latencyMs < 500) {
        dev.log('[NotifPerf] ✅ EXCELLENT latency for $orderId: ${latencyMs}ms');
      }
    }

    // Cleanup to prevent memory leak
    _timestamps.remove('${orderId}_received');
  }

  /// Mark notification rejected (not shown).
  /// Called when notification is silently rejected due to business rules.
  ///
  /// Common rejection reasons:
  /// - 'acceptance_window': Driver accepted an order recently (race condition prevention)
  /// - 'stale (Xms)': Notification is too old
  /// - 'driver_busy': Driver has active trip (Firestore check - should be rare now)
  static void markRejected(String orderId, String reason) {
    if (kDebugMode) {
      dev.log('[NotifPerf] ⛔ Rejected: $orderId | Reason: $reason');
    }

    // Cleanup
    _timestamps.remove('${orderId}_received');
  }

  /// Clear all timestamps (for testing/debugging).
  static void clearAll() {
    _timestamps.clear();
    if (kDebugMode) {
      dev.log('[NotifPerf] 🧹 Cleared all timestamps');
    }
  }
}
