import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/navigator.dart';
import '../features/notifications/new_order_alert_dialog.dart';
import '../features/notifications/providers/snooze_provider.dart';
import 'notification_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Use GlobalKey for router instead of storing BuildContext
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingRoute;
  ProviderContainer? _providerContainer;

  void setProviderContainer(ProviderContainer container) {
    _providerContainer = container;
  }

  Future<void> initialize() async {
    // navigatorKey is now globally imported
    _navigatorKey = appNavigatorKey;

    await _initializeLocalNotifications();
    await _setupFirebaseMessaging();
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
      enableVibration: true,
      playSound: true,
    );

    // Channel for unassigned order reminders (high priority)
    const unassignedOrdersChannel = AndroidNotificationChannel(
      'unassigned_orders',
      'تذكير بطلبات متاحة',
      description: 'تذكيرات بالطلبات المتاحة القريبة منك',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // Channel for order updates (default priority)
    const orderUpdatesChannel = AndroidNotificationChannel(
      'order_updates',
      'تحديثات الطلبات',
      description: 'تحديثات حالة الطلبات الحالية',
      importance: Importance.defaultImportance,
      enableVibration: true,
    );

    // Channel for acceptance confirmations
    const acceptanceChannel = AndroidNotificationChannel(
      'acceptance_confirmations',
      'تأكيد القبول',
      description: 'تأكيدات قبول الطلبات',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(newOrdersChannel);
    await android?.createNotificationChannel(unassignedOrdersChannel);
    await android?.createNotificationChannel(orderUpdatesChannel);
    await android?.createNotificationChannel(acceptanceChannel);
  }

  Future<void> _setupFirebaseMessaging() async {
    // Foreground messages — show local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // NOTE: onMessageOpenedApp and getInitialMessage are handled by
    // BaseFCMService.setupNotificationHandlers (via FCMService in auth_gate).
    // Do NOT add duplicate listeners here.
  }


  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[NotificationService] 🔔 onMessage received: ${message.data}');
    }

    final notificationType = NotificationHelper.resolveType(message.data);
    final orderId = message.data['orderId'] as String?;

    if (kDebugMode) {
      debugPrint('[NotificationService] type=$notificationType, orderId=$orderId');
    }

    // Skip repeated reminders in foreground — driver already sees the orders list
    if (notificationType == 'unassigned_order_reminder') {
      if (kDebugMode) {
        debugPrint('[NotificationService] Skipping reminder in foreground');
      }
      return;
    }

    // Show in-app dialog for new order notifications (data-only message, no notification field)
    if (notificationType == 'new_order' || notificationType == 'new_order_nearby') {
      final data = message.data;
      _showNewOrderAlertDialog(
        orderId: data['orderId'] ?? '',
        pickupLabel: data['pickupLabel'] ?? '${data['pickupLat']}, ${data['pickupLng']}',
        dropoffLabel: data['dropoffLabel'] ?? '${data['dropoffLat']}, ${data['dropoffLng']}',
        price: double.tryParse(data['price'] ?? '0') ?? 0,
        distance: double.tryParse(data['distance'] ?? '0') ?? 0,
      );
      return;
    }

    // For other notification types, require notification payload
    final notification = message.notification;
    if (notification == null) return;

    final payload = jsonEncode(message.data);

    // Use stable ID per order so repeated notifications update instead of stacking
    final notificationId = orderId?.hashCode ?? notification.hashCode;

    // Determine channel
    String channelId;
    String channelName;
    Importance importance;
    Priority priority;

    switch (notificationType) {
      case 'new_order':
      case 'new_order_nearby':
        channelId = 'new_orders';
        channelName = 'طلبات جديدة';
        importance = Importance.high;
        priority = Priority.high;
        break;
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
          onlyAlertOnce: true, // Don't vibrate/sound on updates
        ),
      ),
      payload: payload,
    );
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
    }

    final type = NotificationHelper.resolveType(data);
    final route = NotificationHelper.getRouteFromNotification(type: type);

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

  void _showNewOrderAlertDialog({
    required String orderId,
    required String pickupLabel,
    required String dropoffLabel,
    required double price,
    required double distance,
  }) {
    debugPrint('[NotificationService] 🚀 _showNewOrderAlertDialog called for: $orderId');

    if (_navigatorKey?.currentContext == null) {
      debugPrint('[NotificationService] ❌ Cannot show dialog: no context');
      return;
    }

    final context = _navigatorKey!.currentContext!;

    // Don't show if driver is on active order screen (busy)
    try {
      final currentRoute = GoRouterState.of(context).uri.path;
      if (currentRoute == '/active-order') {
        debugPrint('[NotificationService] Driver is busy, skipping alert');
        return;
      }
    } on Object catch (_) {
      // GoRouterState not available from this context — safe to proceed
    }

    showNewOrderAlertDialog(
      context,
      orderId: orderId,
      pickupLabel: pickupLabel,
      dropoffLabel: dropoffLabel,
      price: price,
      distance: distance,
      onSnooze: () {
        if (_providerContainer == null) {
          debugPrint('[NotificationService] Cannot snooze: ProviderContainer not set');
          return;
        }

        debugPrint('[NotificationService] Scheduling snooze for order: $orderId');

        _providerContainer!.read(snoozeProvider.notifier).scheduleReminder(
          orderId,
          () {
            _showNewOrderAlertDialog(
              orderId: orderId,
              pickupLabel: pickupLabel,
              dropoffLabel: dropoffLabel,
              price: price,
              distance: distance,
            );
          },
        );
      },
    );
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
