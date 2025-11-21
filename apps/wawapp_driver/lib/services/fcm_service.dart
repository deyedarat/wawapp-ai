import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'analytics_service.dart';

/// FCM Service for managing push notification tokens (Driver App)
class FCMService {
  static final FCMService instance = FCMService._internal();
  factory FCMService() => instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentToken;

  /// Initialize FCM service
  Future<void> initialize(BuildContext context) async {
    try {
      final permission = await requestPermission();

      if (!permission) {
        if (kDebugMode) {
          debugPrint('[FCM] Notification permission denied by user');
        }
        return;
      }

      final token = await getToken();

      if (token != null) {
        await saveTokenToFirestore(token);

        _messaging.onTokenRefresh.listen((newToken) {
          if (kDebugMode) {
            debugPrint('[FCM] Token refreshed: ${newToken.substring(0, 20)}...');
          }
          saveTokenToFirestore(newToken);
        });
      }

      // Setup notification tap handlers
      setupNotificationHandlers(context);

      // Initialize dynamic links
      await _initDynamicLinks(context);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Initialization error: $e');
      }
    }
  }

  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
      }

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Permission request error: $e');
      }
      return false;
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();

      if (token != null) {
        _currentToken = token;
        if (kDebugMode) {
          debugPrint('[FCM] Token obtained: ${token.substring(0, 20)}...');
        }
      }

      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Get token error: $e');
      }
      return null;
    }
  }

  /// Save FCM token to Firestore (drivers collection for driver app)
  Future<void> saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('[FCM] Cannot save token: user not authenticated');
        }
        return;
      }

      // IMPORTANT: Driver app saves to 'drivers' collection
      await _firestore.collection('drivers').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('[FCM] Token saved to Firestore for driver: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Save token error: $e');
      }
    }
  }

  Future<void> deleteToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _messaging.deleteToken();

      await _firestore.collection('drivers').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
      });

      _currentToken = null;

      if (kDebugMode) {
        debugPrint('[FCM] Token deleted for driver: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Delete token error: $e');
      }
    }
  }

  String? get currentToken => _currentToken;

  /// Setup notification tap handlers
  void setupNotificationHandlers(BuildContext context) {
    // Handle notification taps when app is in BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Notification tapped (background): ${message.data}');
      }
      _handleNotificationTap(context, message, 'background');
    });

    // Handle notification taps when app is TERMINATED
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          debugPrint('[FCM] Notification tapped (terminated): ${message.data}');
        }
        _handleNotificationTap(context, message, 'terminated');
      }
    });

    // Handle messages when app is in FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Foreground notification: ${message.notification?.title}');
      }

      // Track notification delivery
      final orderId = message.data['orderId'] as String?;
      final type = message.data['type'] as String?;
      if (orderId != null && type != null) {
        AnalyticsService.instance.logNotificationDelivered(
          notificationType: type,
          orderId: orderId,
        );
      }

      // Show in-app snackbar
      if (message.notification != null) {
        _showForegroundNotification(context, message);
      }
    });
  }

  /// Handle notification tap and navigate (DRIVER VERSION)
  void _handleNotificationTap(BuildContext context, RemoteMessage message, String appState) {
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

      // Driver notifications (future use)
      switch (type) {
        case 'new_order_nearby':
          // Navigate to nearby orders screen
          context.go('/nearby');
          break;

        default:
          if (kDebugMode) {
            debugPrint('[FCM] Unknown notification type: $type');
          }
          context.go('/nearby');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Navigation error: $e');
      }
    }
  }

  /// Show in-app notification when app is in foreground
  void _showForegroundNotification(BuildContext context, RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;

    if (title == null || body == null) return;

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'عرض',
          onPressed: () {
            _handleNotificationTap(context, message, 'foreground');
          },
        ),
      ),
    );
  }

  /// Initialize Firebase Dynamic Links
  Future<void> _initDynamicLinks(BuildContext context) async {
    try {
      // Handle initial link (app opened from terminated state via deep link)
      final PendingDynamicLinkData? initialLink =
          await FirebaseDynamicLinks.instance.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(context, initialLink.link);
      }

      // Handle links while app is running (foreground/background)
      FirebaseDynamicLinks.instance.onLink.listen(
        (dynamicLinkData) {
          _handleDeepLink(context, dynamicLinkData.link);
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('[FCM] Dynamic link error: $error');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Dynamic links initialization error: $e');
      }
    }
  }

  /// Handle deep link and navigate (DRIVER VERSION)
  void _handleDeepLink(BuildContext context, Uri deepLink) {
    if (kDebugMode) {
      debugPrint('[FCM] Deep link received: $deepLink');
    }

    // Log analytics
    AnalyticsService.instance.logEvent(
      'deep_link_opened',
      parameters: {
        'link': deepLink.toString(),
        'scheme': deepLink.scheme,
        'path': deepLink.path,
      },
    );

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

  /// Extract orderId from path like: /order/{orderId}/...
  String? _extractOrderId(String path) {
    final regex = RegExp(r'/order/([^/]+)/');
    final match = regex.firstMatch(path);
    return match?.group(1);
  }
}
