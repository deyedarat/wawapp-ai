import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../core/router/navigator.dart';
import '../features/notifications/full_screen_notification_screen.dart';
import '../features/notifications/trip_start_reminder_screen.dart';
import 'notification_helper.dart';
import 'notification_logger.dart';
import 'notification_method_channel.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingRoute;
  Map<String, dynamic>? _pendingNotificationData;
  String? _pendingTripReminderRoute;
  Map<String, dynamic>? _pendingTripReminderData;

  Future<void> initialize() async {
    _navigatorKey = appNavigatorKey;

    await _initializeLocalNotifications();
    await _setupFirebaseMessaging();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createNotificationChannels();

    // Request USE_FULL_SCREEN_INTENT permission for Android 12+ (API 31+)
    await _requestFullScreenIntentPermission();
  }

  /// Request all permissions required for full-screen intent notifications.
  /// - Android 12+ (API 31+): SCHEDULE_EXACT_ALARM
  /// - Android 14+ (API 34+): USE_FULL_SCREEN_INTENT (separate explicit grant)
  Future<void> _requestFullScreenIntentPermission() async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return;

    // 1. Exact alarm permission (Android 12+ / API 31+)
    final canSchedule = await android.canScheduleExactNotifications() ?? false;
    if (kDebugMode) {
      debugPrint(
          '[NotificationService] canScheduleExactNotifications: $canSchedule');
    }
    if (!canSchedule) {
      await android.requestExactAlarmsPermission();
    }

    // 2. USE_FULL_SCREEN_INTENT permission (Android 14+ / API 34+)
    //    requestFullScreenIntentPermission() internally checks if already granted
    //    and only opens Settings if not yet approved by the user.
    try {
      await android.requestFullScreenIntentPermission();
      if (kDebugMode) {
        debugPrint(
            '[NotificationService] requestFullScreenIntentPermission called');
      }
    } catch (e) {
      // Permission request not supported on this Android version — safe to ignore
      if (kDebugMode) {
        debugPrint('[NotificationService] fullScreenIntent permission N/A: $e');
      }
    }
  }

  /// Create Android notification channels.
  ///
  /// v6 channels (with bypassDnd + USAGE_ALARM) are created via Native Kotlin
  /// through NotificationMethodChannel. These handle all order/reminder notifications.
  ///
  /// flutter_local_notifications is only used for non-critical notifications
  /// (acceptance_confirmation, order_updates) which use the default channel.
  Future<void> _createNotificationChannels() async {
    // v6 channels via Native Kotlin (bypassDnd, full-screen intent, USAGE_ALARM)
    try {
      await NotificationMethodChannel.createNotificationChannels();
      if (kDebugMode) {
        debugPrint('[NotificationService] ✅ Native v6 channels created');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationService] ⚠️ Native channel creation failed: $e');
      }
    }

    // Clean up legacy v1-v5 channels (one-time migration)
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      for (final id in [
        'new_orders',
        'new_orders_v2',
        'new_orders_v3',
        'new_orders_v4',
        'new_orders_v5',
        'new_orders_v6',
        'unassigned_orders',
        'unassigned_orders_v2',
        'unassigned_orders_v3',
        'unassigned_orders_v4',
        'unassigned_orders_v5',
        'unassigned_orders_v6',
        'trip_reminders',
        'trip_reminders_v5',
        'trip_reminders_v6',
        'trip_reminders_v7',
      ]) {
        await android.deleteNotificationChannel(id);
      }
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    // Fallback: firebase_messaging onMessage (may never fire if
    // MyFirebaseMessagingService priority=10 intercepts all messages first).
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Primary foreground path: FcmForegroundBridge (Kotlin) forwards the
    // message here when the app is open, since our native service has
    // priority=10 and the firebase_messaging plugin never receives it.
    NotificationMethodChannel.onForegroundMessage.listen((data) {
      _handleForegroundMessage(RemoteMessage(data: data));
    });
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

  String _defaultTitle(String? type) {
    switch (type) {
      case 'acceptance_confirmation':
        return 'تم قبول الطلب';
      case 'order_update':
        return 'تحديث الطلب';
      default:
        return '';
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground message handler
  // ---------------------------------------------------------------------------

  void _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint(
        '[NotificationService] 🔔 onMessage received: ${message.data}',
      );
    }

    final data = message.data;
    final notificationType = NotificationHelper.resolveType(data);
    final orderId = data['orderId'] as String?;

    if (kDebugMode) {
      debugPrint(
        '[NotificationService] type=$notificationType, orderId=$orderId',
      );
    }

    NotificationLogger.instance.log(
      eventType: 'received',
      notificationType: notificationType ?? 'unknown',
      appState: 'foreground',
      orderId: orderId,
    );

    // ── Order notifications → full-screen intent ──
    if (NotificationHelper.isFullScreenType(notificationType)) {
      // trip_start_reminder: show notification but navigate to /active-order
      if (notificationType == 'trip_start_reminder') {
        _showTripReminderNotification(data);
        return;
      }

      // Don't interrupt driver on active trip with new order alerts
      final isBusy = await _isDriverOnActiveTrip();
      if (isBusy) {
        NotificationLogger.instance.log(
          eventType: 'skipped',
          notificationType: notificationType ?? 'unknown',
          appState: 'foreground',
          orderId: orderId,
          escalationLevel: 'active_trip',
        );
        return;
      }

      // Skip if driver already rejected this order
      final oid = data['orderId'] as String?;
      if (oid != null && await _isOrderRejected(oid)) {
        NotificationLogger.instance.log(
          eventType: 'skipped',
          notificationType: notificationType ?? 'unknown',
          appState: 'foreground',
          orderId: oid,
          escalationLevel: 'rejected_order',
        );
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
    final title = notification?.title ??
        (data['title'] as String?) ??
        _defaultTitle(notificationType);
    final body = notification?.body ?? (data['body'] as String?) ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final payload = jsonEncode(data);
    final notificationId = orderId?.hashCode ??
        (orderId != null ? orderId.hashCode : payload.hashCode);

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
      title,
      body,
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

    NotificationLogger.instance.log(
      eventType: 'displayed',
      notificationType: notificationType ?? 'unknown',
      appState: 'foreground',
      displayMode: 'heads_up',
      orderId: orderId,
    );
  }

  // ---------------------------------------------------------------------------
  // Trip start reminder (driver accepted but hasn't started trip)
  // ---------------------------------------------------------------------------

  void _showTripReminderNotification(Map<String, dynamic> data) async {
    final orderId = data['orderId'] as String? ?? '';
    final remaining = data['elapsedMinutes'] as String? ?? '?';

    if (kDebugMode) {
      debugPrint(
        '[NotificationService] 🔔 Trip reminder: order=$orderId, elapsed=$remaining min',
      );
    }

    // FOREGROUND: Skip Native notification (shows as heads-up, not full-screen).
    // Navigate directly to the trip reminder Flutter UI.

    NotificationLogger.instance.log(
      eventType: 'displayed',
      notificationType: 'trip_start_reminder',
      appState: 'foreground',
      displayMode: 'full_screen',
      orderId: orderId,
      escalationLevel: data['escalationLevel'] as String?,
    );

    // Open full-screen trip start reminder UI directly
    final reminderData = TripStartReminderData.tryParse(data);
    if (reminderData != null) {
      _navigateToTripStartReminder(reminderData);
    } else {
      if (!_isOnActiveOrder()) {
        _navigateTo('/active-order');
      }
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
      NotificationLogger.instance.log(
        eventType: 'error',
        notificationType: NotificationHelper.resolveType(data) ?? 'unknown',
        appState: 'foreground',
        orderId: data['orderId'] as String?,
        escalationLevel: 'parse_failed',
      );
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[NotificationService] 🚀 Full-screen notification for order: ${notificationData.orderId}',
      );
    }

    final type = NotificationHelper.resolveType(data);

    // FOREGROUND: Skip Native notification (Android shows it as heads-up, not full-screen).
    // Navigate directly to the full-screen Flutter UI instead.
    // Native notification is only useful in background/locked (handled by main.dart BGHandler).

    NotificationLogger.instance.log(
      eventType: 'displayed',
      notificationType: type ?? 'unknown',
      appState: 'foreground',
      displayMode: 'full_screen',
      orderId: notificationData.orderId,
    );

    // Navigate directly to full-screen route (no heads-up delay)
    _navigateToFullScreen(notificationData);
  }

  /// Navigate to the full-screen notification screen via GoRouter.
  /// Improved with retry mechanism for better reliability.
  void _navigateToFullScreen(FullScreenNotificationData data) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) {
      // App not ready yet — store for later with retry mechanism
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
          '[NotificationService] Context not ready, scheduling retry for full-screen notification',
        );
      }
      _schedulePendingNavigation(() => _navigateToFullScreen(data));
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[NotificationService] ✅ Navigating to /full-screen-notification',
      );
    }

    try {
      ctx.push('/full-screen-notification', extra: data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] ❌ Navigation error: $e');
      }
      // Retry after short delay
      _schedulePendingNavigation(() => _navigateToFullScreen(data));
    }
  }

  /// Navigate to the trip start reminder screen via GoRouter.
  /// Uses same retry mechanism as full-screen notifications.
  void _navigateToTripStartReminder(TripStartReminderData data) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) {
      // App not ready yet — store for later with retry mechanism
      _pendingTripReminderRoute = '/trip-start-reminder';
      _pendingTripReminderData = {
        'orderId': data.orderId,
        'pickupLabel': data.pickupLabel,
        'destinationLabel': data.destinationLabel,
        'elapsedMinutes': data.elapsedMinutes.toString(),
        'createdAt': data.createdAtMs,
      };
      if (kDebugMode) {
        debugPrint(
            '[NotificationService] Context not ready, scheduling retry for trip reminder');
      }
      _schedulePendingNavigation(() => _navigateToTripStartReminder(data));
      return;
    }

    if (kDebugMode) {
      debugPrint('[NotificationService] ✅ Navigating to /trip-start-reminder');
    }

    try {
      ctx.push('/trip-start-reminder', extra: data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] ❌ Navigation error: $e');
      }
      // Retry after short delay
      _schedulePendingNavigation(() => _navigateToTripStartReminder(data));
    }
  }

  /// Schedule a pending navigation to execute after the next frame.
  /// Uses WidgetsBinding.addPostFrameCallback for reliable execution.
  /// Retries up to 3 times with exponential backoff.
  void _schedulePendingNavigation(VoidCallback callback, {int retryCount = 0}) {
    if (retryCount >= 3) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationService] ❌ Max retries reached for pending navigation');
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_navigatorKey?.currentContext != null) {
        // Context is now available, execute callback
        callback();
      } else {
        // Still no context, retry after delay with exponential backoff
        final delayMs = 200 * (retryCount + 1); // 200ms, 400ms, 600ms
        if (kDebugMode) {
          debugPrint(
              '[NotificationService] ⏱️ Retry ${retryCount + 1}/3 after ${delayMs}ms');
        }
        Future.delayed(Duration(milliseconds: delayMs), () {
          _schedulePendingNavigation(callback, retryCount: retryCount + 1);
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Notification tap handler (background / terminated → user taps notification)
  // ---------------------------------------------------------------------------

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final tappedOrderId = data['orderId'] as String?;
      NotificationLogger.instance.log(
        eventType: 'tapped',
        notificationType: NotificationHelper.resolveType(data) ?? 'unknown',
        appState: 'foreground',
        orderId: tappedOrderId,
      );
      // Cancel sound repeats on tap
      if (tappedOrderId != null) {
        NotificationMethodChannel.cancelSoundRepeats(tappedOrderId);
      }
      _navigateFromMessage(data);
    } on Object catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  void _navigateFromMessage(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint(
        '[NotificationService] _navigateFromMessage called with data: $data',
      );
    }

    final type = NotificationHelper.resolveType(data);

    // Full-screen types → route based on specific type
    if (NotificationHelper.isFullScreenType(type)) {
      if (type == 'trip_start_reminder') {
        final reminderData = TripStartReminderData.tryParse(data);
        if (reminderData != null) {
          _navigateToTripStartReminder(reminderData);
          return;
        }
      } else {
        final notificationData = FullScreenNotificationData.tryParse(data);
        if (notificationData != null) {
          _navigateToFullScreen(notificationData);
          return;
        }
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

  /// Check if driver has an active trip (accepted or on_route).
  /// IMPORTANT: Firestore stores status as 'accepted' and 'onRoute' (camelCase)
  Future<bool> _isDriverOnActiveTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Check both driverId and assignedDriverId fields
      var snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('assignedDriverId', isEqualTo: user.uid)
          .where('status', whereIn: ['accepted', 'onRoute'])
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('driverId', isEqualTo: user.uid)
            .where('status', whereIn: ['accepted', 'onRoute'])
            .limit(1)
            .get();
      }

      final hasActiveTrip = snapshot.docs.isNotEmpty;

      if (kDebugMode && hasActiveTrip) {
        final doc = snapshot.docs.first;
        debugPrint(
          '[NotificationService] Driver has active trip: ${doc.id}, status: ${doc.data()['status']}, skipping new order notification',
        );
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
    if (_navigatorKey?.currentContext != null) {
      // Handle pending full-screen notification
      if (_pendingRoute == '/full-screen-notification' &&
          _pendingNotificationData != null) {
        final data = FullScreenNotificationData.tryParse(
          _pendingNotificationData!,
        );
        _pendingRoute = null;
        _pendingNotificationData = null;
        if (data != null) {
          _navigateToFullScreen(data);
          return;
        }
      }

      // Handle pending trip start reminder
      if (_pendingTripReminderRoute == '/trip-start-reminder' &&
          _pendingTripReminderData != null) {
        final data = TripStartReminderData.tryParse(_pendingTripReminderData!);
        _pendingTripReminderRoute = null;
        _pendingTripReminderData = null;
        if (data != null) {
          _navigateToTripStartReminder(data);
          return;
        }
      }

      // Handle other pending routes
      if (_pendingRoute != null) {
        final route = _pendingRoute!;
        _pendingRoute = null;
        _navigatorKey!.currentContext!.go(route);
      }
    }
  }

  /// Called by MissedNotificationRecovery to display a recovered notification.
  void recoverNotification(Map<String, dynamic> data) {
    final notificationType = NotificationHelper.resolveType(data);
    if (notificationType == 'trip_start_reminder') {
      _showTripReminderNotification(data);
    } else if (NotificationHelper.isFullScreenType(notificationType)) {
      _showFullScreenNotification(data);
    }
  }
}
