import 'package:flutter/foundation.dart';
import '../../services/notification_method_channel.dart';

/// Helper class for checking and managing notification-related permissions.
///
/// This class provides a centralized way to:
/// - Check if all critical permissions are granted
/// - Get detailed status of each permission
/// - Request missing permissions
class PermissionHelper {
  /// Check if all critical permissions for call-style notifications are granted.
  ///
  /// Returns true only if ALL of the following are granted:
  /// - Battery optimization is disabled
  /// - Can bypass Do Not Disturb
  /// - Can schedule exact alarms (Android 12+)
  static Future<bool> areAllCriticalPermissionsGranted() async {
    try {
      final statuses = await NotificationMethodChannel.getAllPermissionStatuses();
      final allGranted = statuses['batteryOptimizationDisabled'] == true &&
          statuses['canBypassDnd'] == true &&
          statuses['canScheduleExactAlarms'] == true;

      if (kDebugMode) {
        debugPrint('[PermissionHelper] All critical permissions granted: $allGranted');
        debugPrint('[PermissionHelper] Details: $statuses');
      }

      return allGranted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PermissionHelper] Error checking permissions: $e');
      }
      return false;
    }
  }

  /// Get detailed permission statuses.
  ///
  /// Returns a map with keys:
  /// - batteryOptimizationDisabled: bool
  /// - canBypassDnd: bool
  /// - canScheduleExactAlarms: bool
  static Future<Map<String, bool>> getDetailedPermissionStatuses() async {
    try {
      return await NotificationMethodChannel.getAllPermissionStatuses();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PermissionHelper] Error getting detailed statuses: $e');
      }
      return {
        'batteryOptimizationDisabled': false,
        'canBypassDnd': false,
        'canScheduleExactAlarms': false,
      };
    }
  }

  /// Get a human-readable description of missing permissions.
  ///
  /// Returns a list of missing permission descriptions.
  /// Returns empty list if all permissions are granted.
  static Future<List<String>> getMissingPermissionsDescriptions() async {
    final statuses = await getDetailedPermissionStatuses();
    final List<String> missing = [];

    if (statuses['batteryOptimizationDisabled'] == false) {
      missing.add('Battery Optimization Exemption');
    }
    if (statuses['canBypassDnd'] == false) {
      missing.add('Bypass Do Not Disturb');
    }
    if (statuses['canScheduleExactAlarms'] == false) {
      missing.add('Schedule Exact Alarms');
    }

    return missing;
  }

  /// Request all missing permissions sequentially.
  ///
  /// This method will open Settings for each missing permission.
  /// Returns true if user granted at least one permission.
  static Future<bool> requestMissingPermissions() async {
    final statuses = await getDetailedPermissionStatuses();
    bool anyRequested = false;

    try {
      // 1. Request battery optimization exemption
      if (statuses['batteryOptimizationDisabled'] == false) {
        if (kDebugMode) {
          debugPrint('[PermissionHelper] Requesting battery optimization exemption...');
        }
        await NotificationMethodChannel.requestBatteryOptimizationExemption();
        anyRequested = true;
        // Wait a bit for user to see the dialog
        await Future.delayed(const Duration(seconds: 1));
      }

      // 2. Request DND bypass permission
      if (statuses['canBypassDnd'] == false) {
        if (kDebugMode) {
          debugPrint('[PermissionHelper] Requesting DND bypass permission...');
        }
        await NotificationMethodChannel.requestDndBypassPermission();
        anyRequested = true;
        await Future.delayed(const Duration(seconds: 1));
      }

      // 3. Request exact alarm permission
      if (statuses['canScheduleExactAlarms'] == false) {
        if (kDebugMode) {
          debugPrint('[PermissionHelper] Requesting exact alarm permission...');
        }
        await NotificationMethodChannel.requestExactAlarmPermission();
        anyRequested = true;
      }

      return anyRequested;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PermissionHelper] Error requesting permissions: $e');
      }
      return false;
    }
  }

  /// Get a percentage score for permission completion (0-100).
  ///
  /// Used for showing progress to the user.
  static Future<int> getPermissionCompletionPercentage() async {
    final statuses = await getDetailedPermissionStatuses();
    int granted = 0;
    int total = 3;

    if (statuses['batteryOptimizationDisabled'] == true) granted++;
    if (statuses['canBypassDnd'] == true) granted++;
    if (statuses['canScheduleExactAlarms'] == true) granted++;

    return ((granted / total) * 100).round();
  }
}
