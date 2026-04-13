import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:core_shared/core_shared.dart';
import '../features/notifications/full_screen_notification_screen.dart';
import '../features/notifications/trip_start_reminder_screen.dart';
import 'analytics_service.dart';
import 'notification_logger.dart';

/// Driver-specific FCM service for ride-hailing driver app.
///
/// Extends [BaseFCMService] with driver-specific notification routing.
class FCMService extends BaseFCMService {
  static final FCMService instance = FCMService._internal();
  factory FCMService() => instance;
  FCMService._internal() : super.internal();

  // ===== IMPLEMENT ABSTRACT METHODS =====

  @override
  String getFirestoreCollection() => 'drivers';

  @override
  void handleNotificationTap(
    BuildContext context,
    RemoteMessage message,
    String appState,
  ) {
    try {
      final orderId = message.data['orderId'] as String?;
      final type = message.data['notificationType'] as String? ??
          message.data['type'] as String?;

      if (orderId == null || type == null) {
        if (kDebugMode) {
          debugPrint('[FCM] Invalid notification data: ${message.data}');
        }
        return;
      }

      // Track notification tap
      AnalyticsService.instance.logNotificationTapped(
        notificationType: type,
        orderId: orderId,
        appState: appState,
      );
      NotificationLogger.instance.log(
        eventType: 'tapped',
        notificationType: type,
        appState: appState,
        orderId: orderId,
      );

      if (kDebugMode) {
        debugPrint('[FCM] Navigating to: $type for order: $orderId');
      }

      if (!context.mounted) return;

      // Driver notifications
      switch (type) {
        case 'new_order':
        case 'new_order_nearby':
        case 'unassigned_order_reminder':
          final data = FullScreenNotificationData.tryParse(message.data);
          if (data != null) {
            context.push('/full-screen-notification', extra: data);
          } else {
            context.go('/nearby');
          }
          break;

        case 'trip_start_reminder':
          final reminderData = TripStartReminderData.tryParse(message.data);
          if (reminderData != null) {
            context.push('/trip-start-reminder', extra: reminderData);
          } else {
            context.go('/active-order');
          }
          break;

        case 'order_cancelled_by_client':
        case 'trip_cancelled_by_client':
        case 'order_expired_driver':
          // Navigate to nearby orders (refresh list)
          context.go('/nearby');
          break;

        default:
          if (kDebugMode) {
            debugPrint('[FCM] Unknown notification type: $type');
          }
          context.go('/nearby');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Navigation error: $e');
      }
    }
  }

  @override
  void handleDeepLink(BuildContext context, Uri deepLink) {
    if (kDebugMode) {
      debugPrint('[FCM] Deep link received: $deepLink');
    }

    if (!context.mounted) return;

    final path = deepLink.path;
    final queryParams = deepLink.queryParameters;

    // Route based on path structure
    if (path.contains('/order/') && path.contains('/active')) {
      // Navigate to active order screen (driver app doesn't use orderId in route)
      context.go('/active-order');
    } else if (path.contains('/nearby')) {
      context.go('/nearby');
    } else if (path.contains('/error')) {
      final message = queryParams['message'] ?? 'حدث خطأ غير متوقع';
      if (kDebugMode) {
        debugPrint('[FCM] Error deep link: $message');
      }
      context.go('/nearby');
    } else {
      // Default fallback
      context.go('/nearby');
    }
  }
}
