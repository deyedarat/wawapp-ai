import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../core/router/navigator.dart'; // Add this line
import 'notification_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Use GlobalKey for router instead of storing BuildContext
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingRoute;

  Future<void> initialize() async {
    // navigatorKey is now globally imported
    _navigatorKey = appNavigatorKey;

    await _initializeLocalNotifications();
    await _setupFirebaseMessaging();
    await _handleInitialMessage();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    // Channel for new order notifications (high priority)
    const newOrdersChannel = AndroidNotificationChannel(
      'new_orders',
      'طلبات جديدة',
      description: 'إشعارات الطلبات الجديدة القريبة منك',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      playSound: true,
    );

    // Channel for order updates (default priority)
    const orderUpdatesChannel = AndroidNotificationChannel(
      'order_updates',
      'تحديثات الطلبات',
      description: 'تحديثات حالة الطلبات الحالية',
      importance: Importance.defaultImportance,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(newOrdersChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(orderUpdatesChannel);
  }

  Future<void> _setupFirebaseMessaging() async {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background/terminated app messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  Future<void> _handleInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleColdStartMessage(initialMessage);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      final payload = jsonEncode(message.data);
      final notificationType = message.data['notificationType'] ?? message.data['type'];

      // Determine channel based on notification type
      final channelId = notificationType == 'new_order' ? 'new_orders' : 'order_updates';
      final channelName = notificationType == 'new_order' ? 'طلبات جديدة' : 'تحديثات الطلبات';
      final importance = notificationType == 'new_order' ? Importance.high : Importance.defaultImportance;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: importance,
            priority: notificationType == 'new_order' ? Priority.high : Priority.defaultPriority,
            sound: const RawResourceAndroidNotificationSound('notification'),
            enableVibration: true,
            playSound: true,
          ),
        ),
        payload: payload,
      );
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    _navigateFromMessage(message.data);
  }

  void _handleColdStartMessage(RemoteMessage message) {
    final route = NotificationHelper.getRouteFromNotification(
      type: message.data['type'],
      role: message.data['role'],
    );

    if (route != null) {
      if (_navigatorKey?.currentContext != null) {
        _navigatorKey!.currentContext!.go(route);
      } else {
        _pendingRoute = route;
      }
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _navigateFromMessage(data);
      } on Object catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  void _navigateFromMessage(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint('[NotificationService] _navigateFromMessage called with data: $data');
      debugPrint('[NotificationService] Navigator available: ${_navigatorKey?.currentContext != null}');
    }

    final route = NotificationHelper.getRouteFromNotification(
      type: data['type'],
      role: data['role'],
    );

    if (kDebugMode) {
      debugPrint('[NotificationService] Route from helper: $route');
    }

    if (route != null && _navigatorKey?.currentContext != null) {
      if (kDebugMode) {
        debugPrint('[NotificationService] ✅ Navigating to: $route');
      }
      try {
        _navigatorKey!.currentContext!.go(route);
        if (kDebugMode) {
          debugPrint('[NotificationService] ✅ Navigation successful');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[NotificationService] ❌ Navigation error: $e');
        }
      }
    } else {
      if (kDebugMode) {
        if (route == null) {
          debugPrint('[NotificationService] ❌ Route is null, cannot navigate');
        }
        if (_navigatorKey?.currentContext == null) {
          debugPrint('[NotificationService] ❌ Navigator context is null, cannot navigate');
        }
      }
    }
  }

  void updateContext(BuildContext context) {
    // We don't need to extract navigatorKey from context anymore since we have appNavigatorKey
    _navigatorKey = appNavigatorKey;
    if (_pendingRoute != null && _navigatorKey?.currentContext != null) {
      _navigatorKey!.currentContext!.go(_pendingRoute!);
      _pendingRoute = null;
    }
  }
}
