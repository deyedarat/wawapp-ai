import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battery_optimization_manager.dart';
import 'fcm_token_manager.dart';

/// Comprehensive health monitor for the notification system.
///
/// Monitors:
/// - FCM token validity
/// - Battery optimization status
/// - Notification permission status
/// - Channel health
/// - DND bypass permission
/// - Exact alarm permission
///
/// Provides:
/// - Health score (0-100)
/// - Diagnostic information
/// - Auto-repair capabilities
class NotificationHealthMonitor {
  static final NotificationHealthMonitor _instance =
      NotificationHealthMonitor._internal();
  factory NotificationHealthMonitor() => _instance;
  NotificationHealthMonitor._internal();

  static const _channel = MethodChannel('com.wawapp.driver/notifications');
  static const String _kLastHealthCheckKey = 'notification_health_last_check';
  static const String _kHealthScoreKey = 'notification_health_score';

  int _healthScore = 0;
  DateTime? _lastCheck;

  /// Comprehensive health check.
  ///
  /// Returns health score (0-100) and diagnostic information.
  Future<NotificationHealthReport> checkHealth() async {
    if (kDebugMode) {
      debugPrint('[NotificationHealth] 🏥 Running health check...');
    }

    final checks = <String, bool>{};
    int score = 0;

    // Check 1: FCM Token (25 points)
    final tokenManager = FcmTokenManager();
    final hasValidToken = tokenManager.currentToken != null;
    checks['fcm_token'] = hasValidToken;
    if (hasValidToken) score += 25;

    // Check 2: Battery Optimization (25 points)
    final batteryManager = BatteryOptimizationManager();
    final isExempt = await batteryManager.isExemptFromBatteryOptimization();
    checks['battery_exempt'] = isExempt;
    if (isExempt) score += 25;

    // Check 3: Notification Permission (20 points)
    final hasNotificationPermission = await _checkNotificationPermission();
    checks['notification_permission'] = hasNotificationPermission;
    if (hasNotificationPermission) score += 20;

    // Check 4: DND Bypass (15 points)
    final canBypassDnd = await _checkDndBypass();
    checks['dnd_bypass'] = canBypassDnd;
    if (canBypassDnd) score += 15;

    // Check 5: Exact Alarm Permission (15 points)
    final canScheduleExactAlarms = await _checkExactAlarmPermission();
    checks['exact_alarm'] = canScheduleExactAlarms;
    if (canScheduleExactAlarms) score += 15;

    _healthScore = score;
    _lastCheck = DateTime.now();

    // Save health score
    await _saveHealthScore(score);

    final report = NotificationHealthReport(
      score: score,
      checks: checks,
      timestamp: _lastCheck!,
      recommendations: _generateRecommendations(checks),
    );

    if (kDebugMode) {
      debugPrint('[NotificationHealth] 📊 Health score: $score/100');
      debugPrint('[NotificationHealth] Checks: $checks');
    }

    return report;
  }

  /// Check notification permission status.
  Future<bool> _checkNotificationPermission() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ❌ Error checking permission: $e');
      }
      return false;
    }
  }

  /// Check DND bypass permission.
  Future<bool> _checkDndBypass() async {
    try {
      final result = await _channel.invokeMethod<bool>('canBypassDnd');
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ❌ Error checking DND: ${e.message}');
      }
      return false;
    }
  }

  /// Check exact alarm permission.
  Future<bool> _checkExactAlarmPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ❌ Error checking alarm: ${e.message}');
      }
      return false;
    }
  }

  /// Generate recommendations based on failed checks.
  List<String> _generateRecommendations(Map<String, bool> checks) {
    final recommendations = <String>[];

    if (checks['fcm_token'] == false) {
      recommendations
          .add('FCM Token missing - reinitialize Firebase Messaging');
    }

    if (checks['battery_exempt'] == false) {
      recommendations
          .add('Disable battery optimization for reliable notifications');
    }

    if (checks['notification_permission'] == false) {
      recommendations.add('Grant notification permission');
    }

    if (checks['dnd_bypass'] == false) {
      recommendations.add('Allow app to bypass Do Not Disturb mode');
    }

    if (checks['exact_alarm'] == false) {
      recommendations
          .add('Grant exact alarm permission for timely notifications');
    }

    return recommendations;
  }

  /// Auto-repair notification system.
  ///
  /// Attempts to fix common issues automatically:
  /// - Refresh FCM token
  /// - Request missing permissions
  /// - Recreate notification channels
  Future<bool> autoRepair() async {
    if (kDebugMode) {
      debugPrint('[NotificationHealth] 🔧 Starting auto-repair...');
    }

    bool repaired = false;

    // Refresh FCM token
    try {
      await FcmTokenManager().forceRefresh();
      repaired = true;
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ✅ FCM token refreshed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ❌ Token refresh failed: $e');
      }
    }

    // Request notification permission
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );
      repaired = true;
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ✅ Notification permission requested');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ❌ Permission request failed: $e');
      }
    }

    // Recreate notification channels
    try {
      await _channel.invokeMethod('createNotificationChannels');
      repaired = true;
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ✅ Notification channels recreated');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ❌ Channel recreation failed: $e');
      }
    }

    return repaired;
  }

  /// Save health score locally.
  Future<void> _saveHealthScore(int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kHealthScoreKey, score);
      await prefs.setInt(
        _kLastHealthCheckKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ❌ Error saving score: $e');
      }
    }
  }

  /// Get cached health score.
  int get healthScore => _healthScore;

  /// Get last check timestamp.
  DateTime? get lastCheck => _lastCheck;

  /// Check if health check is needed (every 6 hours).
  Future<bool> needsHealthCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckTimestamp = prefs.getInt(_kLastHealthCheckKey);
      if (lastCheckTimestamp == null) return true;

      final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTimestamp);
      final hoursSinceLastCheck = DateTime.now().difference(lastCheck).inHours;

      return hoursSinceLastCheck >= 6;
    } catch (e) {
      return true;
    }
  }

  /// Log health status to Firestore for monitoring.
  Future<void> logHealthToFirestore(NotificationHealthReport report) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('driver_notification_health')
          .doc(user.uid)
          .set({
        'score': report.score,
        'checks': report.checks,
        'recommendations': report.recommendations,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('[NotificationHealth] ☁️ Health status logged to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationHealth] ❌ Error logging to Firestore: $e');
      }
    }
  }
}

/// Health report containing diagnostic information.
class NotificationHealthReport {
  final int score;
  final Map<String, bool> checks;
  final DateTime timestamp;
  final List<String> recommendations;

  NotificationHealthReport({
    required this.score,
    required this.checks,
    required this.timestamp,
    required this.recommendations,
  });

  bool get isHealthy => score >= 80;
  bool get needsAttention => score < 60;
  bool get isCritical => score < 40;

  String get status {
    if (isCritical) return '🔴 Critical';
    if (needsAttention) return '🟡 Needs Attention';
    if (isHealthy) return '🟢 Healthy';
    return '🟠 Fair';
  }
}
