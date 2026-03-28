import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:core_shared/core_shared.dart';
import 'analytics_service.dart';

/// Client-specific FCM service for ride-hailing client app.
///
/// Extends [BaseFCMService] with client-specific notification routing
/// and conversion tracking for analytics.
class FCMService extends BaseFCMService {
  static final FCMService instance = FCMService._internal();
  factory FCMService() => instance;
  FCMService._internal() : super.internal();

  // Client-specific: Notification source tracking for analytics
  final Map<String, String> _notificationSources = {};

  // ===== IMPLEMENT ABSTRACT METHODS =====

  @override
  String getFirestoreCollection() => 'users';

  @override
  void handleNotificationTap(
    BuildContext context,
    RemoteMessage message,
    String appState,
  ) {
    try {
      final orderId = message.data['orderId'] as String?;
      final type = message.data['type'] as String?;

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

      if (kDebugMode) {
        debugPrint('[FCM] Navigating to: $type for order: $orderId');
      }

      // Navigate based on notification type
      switch (type) {
        case 'driver_accepted':
        case 'driver_on_route':
          // Navigate to order tracking screen
          context.go('/track/$orderId');
          break;

        case 'trip_completed':
          // Store flag for conversion tracking
          _setNotificationSource(orderId, type);
          // Navigate to trip completed/rating screen
          context.go('/trip-completed/$orderId');
          break;

        case 'order_expired':
          // Navigate to home screen
          context.go('/');
          // Show dialog explaining expiration
          _showExpiredDialog(context);
          break;

        default:
          if (kDebugMode) {
            debugPrint('[FCM] Unknown notification type: $type');
          }
          context.go('/');
      }
    } catch (e) {
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

    final path = deepLink.path;
    final queryParams = deepLink.queryParameters;

    // Route based on path structure
    if (path.contains('/order/') && path.contains('/tracking')) {
      final orderId = extractOrderId(path);
      if (orderId != null) {
        context.go('/track/$orderId');
      }
    } else if (path.contains('/order/') && path.contains('/completed')) {
      final orderId = extractOrderId(path);
      if (orderId != null) {
        _setNotificationSource(orderId, 'trip_completed');
        context.go('/trip-completed/$orderId');
      }
    } else if (path.contains('/error')) {
      final message = queryParams['message'] ?? 'حدث خطأ غير متوقع';
      if (kDebugMode) {
        debugPrint('[FCM] Error deep link: $message');
      }
      context.go('/');
    } else {
      // Default fallback
      context.go('/');
    }
  }

  // ===== CLIENT-SPECIFIC METHODS =====

  /// Show dialog when order expired
  void _showExpiredDialog(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('انتهت مهلة الطلب'),
          content:
              const Text('لم يتم العثور على سائق متاح. يمكنك إنشاء طلب جديد.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    });
  }

  /// Store notification source for conversion tracking
  void _setNotificationSource(String orderId, String notificationType) {
    _notificationSources[orderId] = notificationType;
  }

  /// Get notification source (for conversion tracking)
  String? getNotificationSource(String orderId) {
    return _notificationSources[orderId];
  }
}
