import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

/// Base FCM service providing common Firebase Cloud Messaging infrastructure
/// for both client and driver apps.
///
/// This abstract class handles:
/// - FCM token management and persistence
/// - Permission requests
/// - Notification handlers (background/foreground/terminated)
/// - Dynamic Links initialization
/// - Analytics integration
///
/// Apps must extend this class and implement:
/// - [getFirestoreCollection] - Collection name for token storage ('users' or 'drivers')
/// - [handleNotificationTap] - App-specific notification routing logic
/// - [handleDeepLink] - App-specific deep link handling logic
///
/// Example usage:
/// ```dart
/// class ClientFCMService extends BaseFCMService {
///   static final ClientFCMService instance = ClientFCMService._internal();
///   factory ClientFCMService() => instance;
///   ClientFCMService._internal() : super.internal();
///
///   @override
///   String getFirestoreCollection() => 'users';
///
///   @override
///   void handleNotificationTap(BuildContext context, RemoteMessage message, String appState) {
///     // Client-specific routing
///   }
///
///   @override
///   void handleDeepLink(BuildContext context, Uri deepLink) {
///     // Client-specific deep link handling
///   }
/// }
/// ```
abstract class BaseFCMService {
  /// Protected constructor for subclasses
  @protected
  BaseFCMService.internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentToken;

  /// Get current FCM token (cached)
  String? get currentToken => _currentToken;

  // ===== ABSTRACT METHODS (app-specific) =====

  /// Returns the Firestore collection name for token storage.
  ///
  /// - Client app should return: 'users'
  /// - Driver app should return: 'drivers'
  String getFirestoreCollection();

  /// Handles notification tap events with app-specific routing.
  ///
  /// Called when user taps a notification in any app state.
  ///
  /// Parameters:
  /// - [context]: BuildContext for navigation
  /// - [message]: The notification message data
  /// - [appState]: One of 'background', 'terminated', or 'foreground'
  ///
  /// Implementation should:
  /// - Extract notification data (orderId, type, etc.)
  /// - Navigate to appropriate screen
  /// - Log analytics events
  void handleNotificationTap(
    BuildContext context,
    RemoteMessage message,
    String appState,
  );

  /// Handles deep link navigation with app-specific routing.
  ///
  /// Called when app opens via Firebase Dynamic Link.
  ///
  /// Parameters:
  /// - [context]: BuildContext for navigation
  /// - [deepLink]: The deep link URI
  ///
  /// Implementation should:
  /// - Parse deep link path and query parameters
  /// - Navigate to appropriate screen
  /// - Handle error cases
  void handleDeepLink(BuildContext context, Uri deepLink);

  // ===== COMMON METHODS (85% shared code) =====

  /// Initialize FCM service, request permissions, and setup handlers.
  ///
  /// Call this after successful authentication.
  ///
  /// Steps:
  /// 1. Request notification permissions
  /// 2. Get FCM token
  /// 3. Save token to Firestore
  /// 4. Setup token refresh listener
  /// 5. Setup notification handlers
  /// 6. Initialize dynamic links
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
            debugPrint(
                '[FCM] Token refreshed: ${newToken.substring(0, 20)}...');
          }
          saveTokenToFirestore(newToken);
        });
      }

      if (!context.mounted) return;

      // Setup notification tap handlers
      setupNotificationHandlers(context);

      // Initialize dynamic links
      await _initDynamicLinks(context);
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Initialization error: $e');
      }
    }
  }

  /// Request notification permissions from user.
  ///
  /// iOS: Explicit permission dialog
  /// Android: Auto-granted
  ///
  /// Returns true if permission granted, false otherwise.
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
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Permission request error: $e');
      }
      return false;
    }
  }

  /// Get FCM token from Firebase Messaging.
  ///
  /// Returns the token string or null if failed.
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
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Get token error: $e');
      }
      return null;
    }
  }

  /// Save FCM token to Firestore.
  ///
  /// Uses [getFirestoreCollection] to determine the collection name.
  /// Updates both 'fcmToken' and 'fcmTokenUpdatedAt' fields.
  Future<void> saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('[FCM] Cannot save token: user not authenticated');
        }
        return;
      }

      await _firestore
          .collection(getFirestoreCollection())
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('[FCM] Token saved to Firestore for user: ${user.uid}');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Save token error: $e');
      }
    }
  }

  /// Delete FCM token (call on logout).
  ///
  /// Removes token from both Firebase Messaging and Firestore.
  Future<void> deleteToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _messaging.deleteToken();

      await _firestore
          .collection(getFirestoreCollection())
          .doc(user.uid)
          .update({
        'fcmToken': FieldValue.delete(),
      });

      _currentToken = null;

      if (kDebugMode) {
        debugPrint('[FCM] Token deleted for user: ${user.uid}');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Delete token error: $e');
      }
    }
  }

  /// Setup notification handlers for all app states.
  ///
  /// Handles notifications when app is:
  /// - Background: App is running but not in foreground
  /// - Terminated: App was completely closed
  /// - Foreground: App is active and visible
  void setupNotificationHandlers(BuildContext context) {
    // Handle notification taps when app is in BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Notification tapped (background): ${message.data}');
      }
      if (context.mounted) {
        handleNotificationTap(context, message, 'background');
      }
    });

    // Handle notification taps when app is TERMINATED
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          debugPrint('[FCM] Notification tapped (terminated): ${message.data}');
        }
        if (context.mounted) {
          handleNotificationTap(context, message, 'terminated');
        }
      }
    });

    // Handle messages when app is in FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint(
            '[FCM] Foreground notification: ${message.notification?.title}');
      }

      // Show in-app snackbar
      if (message.notification != null && context.mounted) {
        _showForegroundNotification(context, message);
      }
    });
  }

  /// Show in-app notification when app is in foreground.
  ///
  /// Displays a SnackBar with notification title, body, and action button.
  void _showForegroundNotification(
      BuildContext context, RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;

    if (title == null || body == null) return;
    if (!context.mounted) return;

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
            handleNotificationTap(context, message, 'foreground');
          },
        ),
      ),
    );
  }

  /// Initialize Firebase Dynamic Links.
  ///
  /// Handles deep links when:
  /// - App opens from terminated state via deep link
  /// - App receives deep link while running
  Future<void> _initDynamicLinks(BuildContext context) async {
    try {
      // Handle initial link (app opened from terminated state via deep link)
      final PendingDynamicLinkData? initialLink =
          await FirebaseDynamicLinks.instance.getInitialLink();
      if (initialLink != null && context.mounted) {
        handleDeepLink(context, initialLink.link);
      }

      // Handle links while app is running (foreground/background)
      FirebaseDynamicLinks.instance.onLink.listen(
        (dynamicLinkData) {
          if (context.mounted) {
            handleDeepLink(context, dynamicLinkData.link);
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('[FCM] Dynamic link error: $error');
          }
        },
      );
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Dynamic links initialization error: $e');
      }
    }
  }

  /// Extract order ID from deep link path.
  ///
  /// Parses paths like: /order/{orderId}/...
  ///
  /// Returns the order ID or null if not found.
  @protected
  String? extractOrderId(String path) {
    final regex = RegExp(r'/order/([^/]+)/');
    final match = regex.firstMatch(path);
    return match?.group(1);
  }
}
