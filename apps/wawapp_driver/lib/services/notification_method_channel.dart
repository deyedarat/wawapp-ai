import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// MethodChannel for communicating with Android native code for notifications.
///
/// This service provides a bridge between Flutter and Kotlin, allowing us to:
/// - Show full-screen notifications using native Android code
/// - Create notification channels with bypass DND
/// - Request battery optimization exemption
/// - Check permission statuses
class NotificationMethodChannel {
  static const MethodChannel _channel = MethodChannel('com.wawapp.driver/notifications');

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

  /// Get all permission statuses in one call.
  /// Returns a map with the following keys:
  /// - batteryOptimizationDisabled
  /// - canBypassDnd
  /// - canScheduleExactAlarms
  static Future<Map<String, bool>> getAllPermissionStatuses() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('getAllPermissionStatuses');
      if (result == null) {
        return {
          'batteryOptimizationDisabled': false,
          'canBypassDnd': false,
          'canScheduleExactAlarms': false,
        };
      }
      return {
        'batteryOptimizationDisabled': result['batteryOptimizationDisabled'] as bool? ?? false,
        'canBypassDnd': result['canBypassDnd'] as bool? ?? false,
        'canScheduleExactAlarms': result['canScheduleExactAlarms'] as bool? ?? false,
      };
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationMethodChannel] L Error getting permission statuses: ${e.message}');
      }
      return {
        'batteryOptimizationDisabled': false,
        'canBypassDnd': false,
        'canScheduleExactAlarms': false,
      };
    }
  }
}
