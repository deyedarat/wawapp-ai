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
import '../features/notifications/trip_start_reminder_screen.dart';
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
  String? _pendingTripReminderRoute;
  Map<String, dynamic>? _pendingTripReminderData;


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

    // Request USE_FULL_SCREEN_INTENT permission for Android 12+ (API 31+)
    await _requestFullScreenIntentPermission();
  }

  /// Request permission to show full-screen intent notifications (Android 12+)
  Future<void> _requestFullScreenIntentPermission() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      // Check if we can use full-screen intent
      final canUse = await android.canScheduleExactNotifications() ?? false;

      if (kDebugMode) {
        debugPrint('[NotificationService] Can use full-screen intent: $canUse');
      }

      // Request permission if not granted
      if (!canUse) {
        final granted = await android.requestExactAlarmsPermission();
        if (kDebugMode) {
          debugPrint('[NotificationService] Full-screen intent permission granted: $granted');
        }
      }
    }
  }

  /// Create Android notification channels.
  ///
  /// All channels use trip_reminder.wav sound as requested.
  Future<void> _createNotificationChannels() async {
    // Channel 1: New orders — highest priority
    const newOrdersChannel = AndroidNotificationChannel(
      'new_orders_v2',
      'طلبات جديدة',
      description: 'إشعارات الطلبات الجديدة القريبة منك - أولوية قصوى',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('trip_reminder'),
    );

    // Channel 2: Unassigned orders reminder — highest priority
    const unassignedOrdersChannel = AndroidNotificationChannel(
      'unassigned_orders_v2',
      'تذكير بطلبات متاحة',
      description: 'تذكيرات بالطلبات المتاحة القريبة منك - أولوية قصوى',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('trip_reminder'),
    );

    // Channel 3: Order updates — normal priority
    const orderUpdatesChannel = AndroidNotificationChannel(
      'order_updates',
      'تحديثات الطلبات',
      description: 'تحديثات حالة الطلبات الحالية - أولوية عادية',
      importance: Importance.defaultImportance,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('trip_reminder'),
    );

    // Channel 4: Acceptance confirmations — high priority
    const acceptanceChannel = AndroidNotificationChannel(
      'acceptance_confirmations',
      'تأكيد القبول',
      description: 'تأكيدات قبول الطلبات - أولوية عالية',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('trip_reminder'),
    );

    // Channel 5: Trip start reminders — highest priority
    const tripRemindersChannel = AndroidNotificationChannel(
      'trip_reminders',
      'تذكيرات بدء الرحلة',
      description: 'تذكيرات للسائق لبدء الرحلة بعد القبول - أولوية قصوى',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('trip_reminder'),
    );

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Delete ALL old channels to force fresh creation with correct sound
    await android?.deleteNotificationChannel('new_orders');
    await android?.deleteNotificationChannel('unassigned_orders');
    await android?.deleteNotificationChannel('new_orders_v2');
    await android?.deleteNotificationChannel('unassigned_orders_v2');
    await android?.deleteNotificationChannel('trip_reminders');

    await android?.createNotificationChannel(newOrdersChannel);
    await android?.createNotificationChannel(unassignedOrdersChannel);
    await android?.createNotificationChannel(orderUpdatesChannel);
    await android?.createNotificationChannel(acceptanceChannel);
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
    // NOTE: Using 'call' category instead of 'reminder' for more urgent appearance
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
          sound: const RawResourceAndroidNotificationSound('trip_reminder'),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call, // Changed from 'reminder' to 'call' for urgency
          visibility: NotificationVisibility.public,
          onlyAlertOnce: false,
          ongoing: true, // Added: keeps notification persistent
          autoCancel: false, // Added: prevents dismissal on tap
        ),
      ),
      payload: payload,
    );

    // NEW: Open full-screen trip start reminder UI instead of just navigating
    final reminderData = TripStartReminderData.tryParse(data);
    if (reminderData != null) {
      _navigateToTripStartReminder(reminderData);
    } else {
      // Fallback: navigate to active order if parsing fails
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
    final channelId = isReminder ? 'unassigned_orders_v2' : 'new_orders_v2';
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
          sound: const RawResourceAndroidNotificationSound('trip_reminder'),
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
            '[NotificationService] Context not ready, scheduling retry for full-screen notification');
      }
      _schedulePendingNavigation(() => _navigateToFullScreen(data));
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
        'remainingMinutes': data.remainingMinutes.toString(),
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
      debugPrint(
          '[NotificationService] ✅ Navigating to /trip-start-reminder');
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

  /// Check if driver has an active trip (accepted or on_route).
  /// IMPORTANT: Firestore stores status as 'accepted' and 'on_route' (with underscore)
  Future<bool> _isDriverOnActiveTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: user.uid)
          .where('status', whereIn: ['accepted', 'on_route']) // Fixed: 'on_route' not 'onRoute'
          .limit(1)
          .get();

      final hasActiveTrip = snapshot.docs.isNotEmpty;

      if (kDebugMode && hasActiveTrip) {
        final doc = snapshot.docs.first;
        debugPrint('[NotificationService] Driver has active trip: ${doc.id}, status: ${doc.data()['status']}, skipping new order notification');
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
        final data =
            FullScreenNotificationData.tryParse(_pendingNotificationData!);
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
        final data =
            TripStartReminderData.tryParse(_pendingTripReminderData!);
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
}
