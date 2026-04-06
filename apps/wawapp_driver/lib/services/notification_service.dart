import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    const newOrdersChannel = AndroidNotificationChannel(
      'new_orders',
      'طلبات جديدة',
      description: 'إشعارات الطلبات الجديدة القريبة منك',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    const unassignedOrdersChannel = AndroidNotificationChannel(
      'unassigned_orders',
      'تذكير بطلبات متاحة',
      description: 'تذكيرات بالطلبات المتاحة القريبة منك',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
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

    // Channel for trip start reminders — high priority
    const tripRemindersChannel = AndroidNotificationChannel(
      'trip_reminders',
      'تذكيرات بدء الرحلة',
      description: 'تذكيرات للسائق لبدء الرحلة بعد القبول',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    await android?.createNotificationChannel(tripRemindersChannel);
  }

  Future<void> _setupFirebaseMessaging() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  /// Determine notification color based on type
  Color _getNotificationColor(String notificationType) {
    switch (notificationType) {
      case 'order_cancelled':
      case 'order_cancelled_by_driver':
      case 'timeout_expired':
      case 'insufficient_balance':
        return const Color(0xFFE53935); // Red
      case 'new_order':
      case 'unassigned_order_reminder':
      case 'acceptance_confirmation':
        return const Color(0xFFFDD835); // Yellow
      case 'trip_start_reminder':
      case 'order_update':
      default:
        return const Color(0xFF1976D2); // Blue
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground message handler
  // ---------------------------------------------------------------------------

  void _handleForegroundMessage(RemoteMessage message) async {
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
      // trip_start_reminder: show notification but navigate to /active-order
      if (notificationType == 'trip_start_reminder') {
        _showTripReminderNotification(data);
        return;
      }

      // Don't interrupt driver on active trip with new order alerts
      // Only block if driver has STARTED the trip (on_route status)
      final isBusy = await _isDriverOnActiveTrip();
      if (isBusy) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Driver is on active trip (on_route), skipping new order notification');
        }
        return;
      }

      // Skip if driver already rejected this order
      final oid = data['orderId'] as String?;
      if (oid != null && await _isOrderRejected(oid)) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Order $oid was rejected, skipping');
        }
        return;
      }

      _showFullScreenNotification(data);
      return;
    }

    // ── timeout_expired → clear reminders + navigate to /nearby ──
    if (notificationType == 'timeout_expired') {
      final oid = data['orderId'] as String?;
      if (oid != null) {
        _localNotifications.cancel(oid.hashCode);
      }
      _navigateTo('/nearby');
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

    final color = _getNotificationColor(notificationType ?? '');

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
          color: color,
          colorized: true,
          enableVibration: true,
          playSound: true,
          onlyAlertOnce: true,
        ),
      ),
      payload: payload,
    );
  }

  // ---------------------------------------------------------------------------
  // Trip start reminder (driver accepted but hasn't started trip)
  // ---------------------------------------------------------------------------

  void _showTripReminderNotification(Map<String, dynamic> data) {
    final orderId = data['orderId'] as String? ?? '';
    final remaining = data['remainingMinutes'] as String? ?? '?';
    final pickupLabel = data['pickupLabel'] as String? ?? 'موقع الاستلام';
    final payload = jsonEncode(data);

    if (kDebugMode) {
      debugPrint(
          '[NotificationService] 🔔 Trip reminder: order=$orderId, remaining=$remaining min');
    }

    final color = _getNotificationColor('trip_start_reminder');

    // Show/update system notification (same ID → updates in place)
    _localNotifications.show(
      orderId.hashCode,
      'هل وصلت للعميل؟',
      'لديك $remaining دقائق لبدء الرحلة — $pickupLabel',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'trip_reminders',
          'تذكيرات بدء الرحلة',
          importance: Importance.max,
          priority: Priority.max,
          color: color,
          colorized: true,
          enableVibration: true,
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          onlyAlertOnce: false,
        ),
      ),
      payload: payload,
    );

    // Navigate to active order if not already there
    if (!_isOnActiveOrder()) {
      _navigateTo('/active-order');
    }
  }

  /// Simple navigation helper.
  void _navigateTo(String route) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) {
      _pendingRoute = route;
      return;
    }
    try {
      ctx.go(route);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] ❌ Navigation error: $e');
      }
    }
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

    final color = _getNotificationColor(type ?? '');
    final payload = jsonEncode(data);
    final notificationId = notificationData.orderId.hashCode;

    // Show system notification with full-screen intent (call-style).
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
          color: color,
          colorized: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          onlyAlertOnce: false,
          ongoing: true,
          autoCancel: false,
          timeoutAfter: 60000,
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

  /// Check if driver rejected this order.
  Future<bool> _isOrderRejected(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('driver_rejected_orders')
          .where('driverId', isEqualTo: user.uid)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } on Object catch (_) {
      return false;
    }
  }

  /// Check if driver has an active trip that has STARTED (on_route status).
  /// Returns true only if driver is actively driving (status = on_route).
  /// Returns false if driver accepted but hasn't started trip yet (status = accepted).
  Future<bool> _isDriverOnActiveTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'on_route')
          .limit(1)
          .get();

      final hasActiveTrip = snapshot.docs.isNotEmpty;

      if (kDebugMode && hasActiveTrip) {
        debugPrint('[NotificationService] Driver has active trip in progress (on_route)');
      }

      return hasActiveTrip;
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Error checking active trip: $e');
      }
      return false;
    }
  }

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
