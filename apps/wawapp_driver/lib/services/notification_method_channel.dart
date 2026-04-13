import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// MethodChannel for communicating with Android native code for notifications.
///
/// This service provides a bridge between Flutter and Kotlin, allowing us to:
/// - Show full-screen notifications using native Android code
/// - Create notification channels with bypass DND
/// - Request battery optimization exemption
/// - Check permission statuses
/// - Receive intent data from native notification accept action
class NotificationMethodChannel {
  static const MethodChannel _channel = MethodChannel('com.wawapp.driver/notifications');
  static const MethodChannel _intentChannel = MethodChannel('com.wawapp.driver/intent_data');

  /// Show a full-screen notification using native Android code.
  /// This ensures maximum reliability across all Android versions and manufacturers.
  ///
  /// Parameters:
  /// - [orderId]: Unique ID of the order
  /// - [title]: Notification title
  /// - [body]: Notification body
  /// - [pickupLabel]: Pickup location label
  /// - [dropoffLabel]: Dropoff location label
  /// - [price]: Order price
  /// - [distance]: Order distance in km
  /// - [createdAt]: Order creation timestamp (milliseconds since epoch)
  /// - [notificationType]: Type of notification (new_order, unassigned_order_reminder, trip_start_reminder)
  static Future<void> showFullScreenNotification({
    required String orderId,
    required String title,
    required String body,
    required String pickupLabel,
    required String dropoffLabel,
    required double price,
    required double distance,
    required int createdAt,
    required String notificationType,
  }) async {
    try {
      await _channel.invokeMethod('showFullScreenNotification', {
        'orderId': orderId,
        'title': title,
        'body': body,
        'pickupLabel': pickupLabel,
        'dropoffLabel': dropoffLabel,
        'price': price,
        'distance': distance,
        'createdAt': createdAt,
        'notificationType': notificationType,
      });
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel]  Full-screen notification sent via native code');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error: ${e.message}');
      }
      rethrow;
    }
  }

  /// Create notification channels using native Android code.
  /// This ensures channels are created with bypass DND and maximum priority.
  static Future<void> createNotificationChannels() async {
    try {
      await _channel.invokeMethod('createNotificationChannels');
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel]  Notification channels created via native code');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error creating channels: ${e.message}');
      }
      rethrow;
    }
  }

  /// Request battery optimization exemption for the app.
  /// This is critical for ensuring notifications work reliably in background.
  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final bool? result = await _channel.invokeMethod('requestBatteryOptimizationExemption');
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] Battery optimization exemption: ${result == true ? "Granted" : "Denied"}');
      }
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error requesting battery exemption: ${e.message}');
      }
      return false;
    }
  }

  /// Check if battery optimization is currently disabled for this app.
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final bool? result = await _channel.invokeMethod('isBatteryOptimizationDisabled');
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error checking battery optimization: ${e.message}');
      }
      return false;
    }
  }

  /// Check if the app can bypass Do Not Disturb mode.
  static Future<bool> canBypassDnd() async {
    try {
      final bool? result = await _channel.invokeMethod('canBypassDnd');
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error checking DND bypass: ${e.message}');
      }
      return false;
    }
  }

  /// Request permission to bypass Do Not Disturb mode.
  static Future<bool> requestDndBypassPermission() async {
    try {
      final bool? result = await _channel.invokeMethod('requestDndBypassPermission');
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] DND bypass permission: ${result == true ? "Granted" : "Denied"}');
      }
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error requesting DND bypass: ${e.message}');
      }
      return false;
    }
  }

  /// Check if exact alarm permission is granted (Android 12+).
  static Future<bool> canScheduleExactAlarms() async {
    try {
      final bool? result = await _channel.invokeMethod('canScheduleExactAlarms');
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error checking exact alarms: ${e.message}');
      }
      return false;
    }
  }

  /// Request exact alarm permission (Android 12+).
  static Future<bool> requestExactAlarmPermission() async {
    try {
      final bool? result = await _channel.invokeMethod('requestExactAlarmPermission');
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] Exact alarm permission: ${result == true ? "Granted" : "Denied"}');
      }
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error requesting exact alarms: ${e.message}');
      }
      return false;
    }
  }

  /// Cancel pending sound repeats for an order.
  /// Call when order is accepted, rejected, or notification is tapped from Flutter.
  static Future<void> cancelSoundRepeats(String orderId) async {
    try {
      await _channel.invokeMethod('cancelSoundRepeats', {'orderId': orderId});
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] Error cancelling sound repeats: ${e.message}');
      }
    }
  }

  /// Check if the app can use full-screen intent (Android 14+).
  /// This permission is required for full-screen notifications on Android 14+.
  static Future<bool> canUseFullScreenIntent() async {
    try {
      final bool? result = await _channel.invokeMethod('canUseFullScreenIntent');
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error checking full-screen intent: ${e.message}');
      }
      return false;
    }
  }

  /// Request permission to use full-screen intent (Android 14+).
  /// Opens system settings for the user to grant the permission.
  static Future<bool> requestFullScreenIntentPermission() async {
    try {
      final bool? result = await _channel.invokeMethod('requestFullScreenIntentPermission');
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] Full-screen intent permission: ${result == true ? "Granted" : "Denied"}');
      }
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error requesting full-screen intent: ${e.message}');
      }
      return false;
    }
  }

  /// Get all permission statuses in one call.
  /// Returns a map with the following keys:
  /// - batteryOptimizationDisabled
  /// - canBypassDnd
  /// - canScheduleExactAlarms
  /// - canUseFullScreenIntent (Android 14+)
  static Future<Map<String, bool>> getAllPermissionStatuses() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('getAllPermissionStatuses');
      if (result == null) {
        return {
          'batteryOptimizationDisabled': false,
          'canBypassDnd': false,
          'canScheduleExactAlarms': false,
          'canUseFullScreenIntent': false,
        };
      }
      return {
        'batteryOptimizationDisabled': result['batteryOptimizationDisabled'] as bool? ?? false,
        'canBypassDnd': result['canBypassDnd'] as bool? ?? false,
        'canScheduleExactAlarms': result['canScheduleExactAlarms'] as bool? ?? false,
        'canUseFullScreenIntent': result['canUseFullScreenIntent'] as bool? ?? false,
      };
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error getting permission statuses: ${e.message}');
      }
      return {
        'batteryOptimizationDisabled': false,
        'canBypassDnd': false,
        'canScheduleExactAlarms': false,
        'canUseFullScreenIntent': false,
      };
    }
  }

  /// Get intent data from MainActivity (when user accepts notification).
  /// Returns null if no intent data available.
  /// Returns a map with keys: orderId, notificationType, action
  static Future<Map<String, String?>?> getIntentData() async {
    try {
      final Map<dynamic, dynamic>? result = await _intentChannel.invokeMethod('getIntentData');
      if (result == null) return null;

      return {
        'orderId': result['orderId'] as String?,
        'notificationType': result['notificationType'] as String?,
        'action': result['action'] as String?,
      };
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] Error getting intent data: ${e.message}');
      }
      return null;
    }
  }

  /// Clear intent data after handling (prevents duplicate handling).
  static Future<void> clearIntentData() async {
    try {
      await _intentChannel.invokeMethod('clearIntentData');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] Error clearing intent data: ${e.message}');
      }
    }
  }
}
