import 'package:core_shared/core_shared.dart';
import 'package:flutter/foundation.dart';

/// Low-noise auth logger for PIN and router events
///
/// Features:
/// - Only logs PinStatus transitions and router redirects
/// - Includes Crashlytics breadcrumbs in release mode (if available)
/// - Debug prints in debug mode
/// - Rate-limited to reduce log spam
class AuthLogger {
  static const String _prefix = '[AUTH]';
  static DateTime? _lastLogTime;
  static const Duration _minLogInterval = Duration(milliseconds: 100);

  /// Log PIN status transition
  static void logPinStatusChange(String oldStatus, String newStatus, String? userId) {
    if (!_shouldLog()) return;

    final msg = '$_prefix [PIN] Status: $oldStatus → $newStatus | uid=${userId ?? 'null'}';
    
    if (kDebugMode) {
      debugPrint(msg);
    }
    
    // Add Crashlytics breadcrumb (safe - no-op if not initialized)
    CrashlyticsObserver.logEvent('pin_status_change', {
      'old_status': oldStatus,
      'new_status': newStatus,
      'user_id': userId ?? 'null',
    });
  }

  /// Log router redirect decision
  static void logRouterRedirect(String from, String to, String reason, String? userId) {
    if (!_shouldLog()) return;

    final msg = '$_prefix [ROUTER] $from → $to | Reason: $reason | uid=${userId ?? 'null'}';
    
    if (kDebugMode) {
      debugPrint(msg);
    }

    // Add Crashlytics breadcrumb (safe - no-op if not initialized)
    CrashlyticsObserver.logEvent('router_redirect', {
      'from': from,
      'to': to,
      'reason': reason,
      'user_id': userId ?? 'null',
    });
  }

  /// Log auth gate event
  static void logAuthGate(String message, String? userId) {
    if (!_shouldLog()) return;

    final msg = '$_prefix [GATE] $message | uid=${userId ?? 'null'}';
    
    if (kDebugMode) {
      debugPrint(msg);
    }
  }

  /// Rate limiting: prevent log spam
  static bool _shouldLog() {
    final now = DateTime.now();
    if (_lastLogTime != null && now.difference(_lastLogTime!) < _minLogInterval) {
      return false;
    }
    _lastLogTime = now;
    return true;
  }
}
