import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages battery optimization exemption for reliable background notifications.
///
/// Android's battery optimization (Doze Mode) can kill background processes,
/// preventing notifications from being delivered. This service:
/// - Checks if app is exempt from battery optimization
/// - Requests exemption from user
/// - Tracks exemption status
/// - Shows periodic reminders if not exempt
class BatteryOptimizationManager {
  static final BatteryOptimizationManager _instance =
      BatteryOptimizationManager._internal();
  factory BatteryOptimizationManager() => _instance;
  BatteryOptimizationManager._internal();

  static const _channel = MethodChannel('com.wawapp.driver/notifications');
  static const String _kExemptionRequestedKey = 'battery_exemption_requested';
  static const String _kLastCheckTimestampKey = 'battery_exemption_last_check';

  bool? _isExempt;

  /// Check if app is exempt from battery optimization.
  Future<bool> isExemptFromBatteryOptimization() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      _isExempt = result ?? false;

      if (kDebugMode) {
        debugPrint('[BatteryOptimization] Status: ${_isExempt! ? "✅ Exempt" : "❌ Not exempt"}');
      }

      return _isExempt!;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[BatteryOptimization] ❌ Error checking status: ${e.message}');
      }
      return false;
    }
  }

  /// Request battery optimization exemption from user.
  ///
  /// Opens system settings where user can disable battery optimization
  /// for this app. Returns true if user already granted exemption or
  /// successfully navigated to settings.
  Future<bool> requestExemption() async {
    // Check if already exempt
    final isExempt = await isExemptFromBatteryOptimization();
    if (isExempt) {
      if (kDebugMode) {
        debugPrint('[BatteryOptimization] ✅ Already exempt, no action needed');
      }
      return true;
    }

    try {
      // Request exemption (opens system settings)
      final result = await _channel.invokeMethod<bool>('requestBatteryOptimizationExemption');

      // Mark that we've requested exemption
      await _markExemptionRequested();

      if (kDebugMode) {
        debugPrint('[BatteryOptimization] Request result: $result');
      }

      // Check status again after request
      await Future.delayed(const Duration(milliseconds: 500));
      return await isExemptFromBatteryOptimization();
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[BatteryOptimization] ❌ Error requesting exemption: ${e.message}');
      }
      return false;
    }
  }

  /// Check if we should show exemption request dialog.
  ///
  /// Returns true if:
  /// - App is not exempt
  /// - We haven't asked recently (last 24 hours)
  Future<bool> shouldRequestExemption() async {
    // Check if already exempt
    final isExempt = await isExemptFromBatteryOptimization();
    if (isExempt) return false;

    // Check if we asked recently
    final lastCheck = await _getLastCheckTimestamp();
    if (lastCheck != null) {
      final hoursSinceLastCheck =
          DateTime.now().difference(lastCheck).inHours;
      if (hoursSinceLastCheck < 24) {
        if (kDebugMode) {
          debugPrint(
            '[BatteryOptimization] ⏱️ Asked ${hoursSinceLastCheck}h ago, waiting...',
          );
        }
        return false;
      }
    }

    return true;
  }

  /// Mark that we've requested exemption.
  Future<void> _markExemptionRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kExemptionRequestedKey, true);
      await prefs.setInt(
        _kLastCheckTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BatteryOptimization] ❌ Error marking request: $e');
      }
    }
  }

  /// Get timestamp of last exemption check.
  Future<DateTime?> _getLastCheckTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_kLastCheckTimestampKey);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BatteryOptimization] ❌ Error getting timestamp: $e');
      }
      return null;
    }
  }

  /// Get cached exemption status.
  bool? get cachedExemptionStatus => _isExempt;

  /// Force recheck exemption status.
  Future<void> recheckStatus() async {
    await isExemptFromBatteryOptimization();
  }
}
