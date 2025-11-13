import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'notification_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  BuildContext? _context;
  String? _pendingRoute;

  Future<void> initialize(BuildContext context) async {
    _context = context;
    
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
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails('default', 'Default'),
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
      if (_context != null) {
        _context!.go(route);
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
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  void _navigateFromMessage(Map<String, dynamic> data) {
    final route = NotificationHelper.getRouteFromNotification(
      type: data['type'],
      role: data['role'],
    );
    
    if (route != null && _context != null) {
      _context!.go(route);
    }
  }

  void updateContext(BuildContext context) {
    _context = context;
    if (_pendingRoute != null) {
      context.go(_pendingRoute!);
      _pendingRoute = null;
    }
  }
}