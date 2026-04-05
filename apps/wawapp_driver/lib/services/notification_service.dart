import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../core/router/navigator.dart';
import '../features/notifications/full_screen_notification_screen.dart';
import 'notification_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingRoute;
  Map<String, dynamic>? _pendingNotificationData;


  Future<void> initialize() async {
    _navigatorKey = appNavigatorKey;

    await _initializeLocalNotifications();
    await _setupFirebaseMessaging();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createNotificationChannels();
  }

  /// Custom sound for order notifications (references res/raw/new_order.mp3)
  static const _orderSound =
      RawResourceAndroidNotificationSound('new_order');

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    const newOrdersChannel = AndroidNotificationChannel(
      'new_orders',
      'طلبات جديدة',
      description: 'إشعارات الطلبات الجديدة القريبة منك',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: _orderSound,
    );

    const unassignedOrdersChannel = AndroidNotificationChannel(
      'unassigned_orders',
      'تذكير بطلبات متاحة',
      description: 'تذكيرات بالطلبات المتاحة القريبة منك',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: _orderSound,
    );

    const orderUpdatesChannel = AndroidNotificationChannel(
      'order_updates',
      'تحديثات الطلبات',
      description: 'تحديثات حالة الطلبات الحالية',
      importance: Importance.defaultImportance,
      enableVibration: true,
    );

    const acceptanceChannel = AndroidNotificationChannel(
      'acceptance_confirmations',
      'تأكيد القبول',
      description: 'تأكيدات قبول الطلبات',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(newOrdersChannel);
    await android?.createNotificationChannel(unassignedOrdersChannel);
    await android?.createNotificationChannel(orderUpdatesChannel);
    await android?.createNotificationChannel(acceptanceChannel);
  }

  Future<void> _setupFirebaseMessaging() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  // ---------------------------------------------------------------------------
  // Foreground message handler
  // ---------------------------------------------------------------------------

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint(
          '[NotificationService] 🔔 onMessage received: ${message.data}');
    }

    final data = message.data;
    final notificationType = NotificationHelper.resolveType(data);
    final orderId = data['orderId'] as String?;

    if (kDebugMode) {
      debugPrint(
          '[NotificationService] type=$notificationType, orderId=$orderId');
    }

    // ── Order notifications → full-screen intent ──
    if (NotificationHelper.isFullScreenType(notificationType)) {
      // Don't interrupt driver on active trip
      if (_isOnActiveOrder()) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Driver is busy, skipping');
        }
        return;
      }

      _showFullScreenNotification(data);
      return;
    }

    // ── Other notification types → standard notification ──
    final notification = message.notification;
    if (notification == null) return;

    final payload = jsonEncode(data);
    final notificationId = orderId?.hashCode ?? notification.hashCode;

    String channelId;
    String channelName;
    Importance importance;
    Priority priority;

    switch (notificationType) {
      case 'acceptance_confirmation':
        channelId = 'acceptance_confirmations';
        channelName = 'تأكيد القبول';
        importance = Importance.high;
        priority = Priority.high;
        break;
      default:
        channelId = 'order_updates';
        channelName = 'تحديثات الطلبات';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
    }

    _localNotifications.show(
      notificationId,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: importance,
          priority: priority,
          enableVibration: true,
          playSound: true,
          onlyAlertOnce: true,
        ),
      ),
      payload: payload,
    );
  }

  // ---------------------------------------------------------------------------
  // Full-screen notification (new_order / unassigned_order_reminder)
  // ---------------------------------------------------------------------------

  void _showFullScreenNotification(Map<String, dynamic> data) {
    final notificationData = FullScreenNotificationData.tryParse(data);
    if (notificationData == null) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationService] ❌ Invalid notification data: $data');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
          '[NotificationService] 🚀 Full-screen notification for order: ${notificationData.orderId}');
    }

    final type = NotificationHelper.resolveType(data);
    final isReminder = type == 'unassigned_order_reminder';
    final channelId = isReminder ? 'unassigned_orders' : 'new_orders';
    final channelName = isReminder ? 'تذكير بطلبات متاحة' : 'طلبات جديدة';

    final payload = jsonEncode(data);
    final notificationId = notificationData.orderId.hashCode;

    // Show system notification with full-screen intent.
    // On lock screen / screen off → launches FullScreenNotificationScreen.
    // On foreground → shows heads-up notification; we also navigate directly.
    _localNotifications.show(
      notificationId,
      'طلب جديد قريب منك',
      '${notificationData.pickupLabel} → ${notificationData.dropoffLabel}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          sound: _orderSound,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          onlyAlertOnce: false,
        ),
      ),
      payload: payload,
    );

    // In foreground: navigate directly to full-screen route
    _navigateToFullScreen(notificationData);
  }

  /// Navigate to the full-screen notification screen via GoRouter.
  void _navigateToFullScreen(FullScreenNotificationData data) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) {
      // App not ready yet — store for later
      _pendingRoute = '/full-screen-notification';
      _pendingNotificationData = {
        'orderId': data.orderId,
        'pickupLabel': data.pickupLabel,
        'dropoffLabel': data.dropoffLabel,
        'price': data.price,
        'distance': data.distance,
        'createdAt': data.createdAtMs,
      };
      if (kDebugMode) {
        debugPrint(
            '[NotificationService] Context not ready, queued pending route');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
          '[NotificationService] ✅ Navigating to /full-screen-notification');
    }

    try {
      ctx.push('/full-screen-notification', extra: data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] ❌ Navigation error: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Notification tap handler (background / terminated → user taps notification)
  // ---------------------------------------------------------------------------

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromMessage(data);
    } on Object catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  void _navigateFromMessage(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint(
          '[NotificationService] _navigateFromMessage called with data: $data');
    }

    final type = NotificationHelper.resolveType(data);

    // Full-screen types → navigate to full-screen notification screen
    if (NotificationHelper.isFullScreenType(type)) {
      final notificationData = FullScreenNotificationData.tryParse(data);
      if (notificationData != null) {
        _navigateToFullScreen(notificationData);
        return;
      }
    }

    // Other types → use standard route mapping
    final route = NotificationHelper.getRouteFromNotification(type: type);

    if (kDebugMode) {
      debugPrint('[NotificationService] Route from helper: $route');
    }

    if (route != null && _navigatorKey?.currentContext != null) {
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
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Check if driver is currently on the active order screen.
  bool _isOnActiveOrder() {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return false;
    try {
      return GoRouterState.of(ctx).uri.path == '/active-order';
    } on Object catch (_) {
      return false;
    }
  }

  void updateContext(BuildContext context) {
    _navigatorKey = appNavigatorKey;

    // Flush any pending navigation from notifications received before context was ready
    if (_pendingRoute != null && _navigatorKey?.currentContext != null) {
      final route = _pendingRoute!;
      _pendingRoute = null;

      if (route == '/full-screen-notification' &&
          _pendingNotificationData != null) {
        final data =
            FullScreenNotificationData.tryParse(_pendingNotificationData!);
        _pendingNotificationData = null;
        if (data != null) {
          _navigateToFullScreen(data);
          return;
        }
      }

      _navigatorKey!.currentContext!.go(route);
    }
  }
}
