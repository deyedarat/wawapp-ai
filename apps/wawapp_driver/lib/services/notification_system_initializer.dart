import 'package:flutter/foundation.dart';

import 'battery_optimization_manager.dart';
import 'fcm_token_manager.dart';
import 'missed_notification_recovery.dart';
import 'notification_health_monitor.dart';
import 'orders_service.dart';

/// Post-login notification system initializer.
///
/// Called after successful authentication to initialize services that require
/// a logged-in user (Firestore access, etc.).
class NotificationSystemInitializer {
  static bool _initialized = false;

  /// Initialize notification system after login.
  ///
  /// Should be called once after successful authentication.
  /// Safe to call multiple times (will skip if already initialized).
  static Future<void> initializeAfterLogin() async {
    if (_initialized) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationSystemInitializer] ✅ Already initialized, skipping');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
          '[NotificationSystemInitializer] 🚀 Starting post-login initialization...');
    }

    try {
      // 1. Refresh FCM token to sync with backend
      await FcmTokenManager().forceRefresh();

      // 2. Check and request battery optimization exemption if needed
      final batteryManager = BatteryOptimizationManager();
      if (await batteryManager.shouldRequestExemption()) {
        if (kDebugMode) {
          debugPrint(
              '[NotificationSystemInitializer] 🔋 Requesting battery exemption...');
        }
        await batteryManager.requestExemption();
      }

      // 3. Run health check
      final monitor = NotificationHealthMonitor();
      final report = await monitor.checkHealth();
      await monitor.logHealthToFirestore(report);

      if (kDebugMode) {
        debugPrint(
            '[NotificationSystemInitializer] 📊 Health score: ${report.score}/100');
      }

      // 4. Auto-repair if needed
      if (report.needsAttention) {
        if (kDebugMode) {
          debugPrint(
              '[NotificationSystemInitializer] 🔧 Running auto-repair...');
        }
        await monitor.autoRepair();
      }

      // 5. Sync native active trip flag with Firestore
      await OrdersService.syncActiveTripFlagOnStartup();

      // 6. Start missed notification recovery
      await MissedNotificationRecovery().start();

      _initialized = true;

      if (kDebugMode) {
        debugPrint(
            '[NotificationSystemInitializer] ✅ Post-login initialization complete');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationSystemInitializer] ❌ Initialization error: $e');
      }
    }
  }

  /// Reset initialization flag (for testing or logout).
  static void reset() {
    _initialized = false;
    MissedNotificationRecovery().stop();

    if (kDebugMode) {
      debugPrint('[NotificationSystemInitializer] 🔄 Reset complete');
    }
  }

  /// Check if system is initialized.
  static bool get isInitialized => _initialized;
}
