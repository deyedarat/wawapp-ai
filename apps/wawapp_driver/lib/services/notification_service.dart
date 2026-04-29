import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/router/navigator.dart';
import '../features/notifications/full_screen_notification_screen.dart';
import '../features/notifications/trip_start_reminder_screen.dart';
import 'acceptance_lock_manager.dart';
import 'notification_dedup_service.dart';
import 'notification_helper.dart';
import 'notification_logger.dart';
import 'notification_method_channel.dart';
import 'orders_service.dart';

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

  // Local state to track recently accepted/rejected orders (prevents stale notifications)
  final Map<String, DateTime> _recentlyProcessedOrders = {};
  static const Duration _staleNotificationWindow = Duration(minutes: 2);

  // Debouncing state to prevent duplicate notifications
  final Map<String, DateTime> _recentlyShownNotifications = {};
  static const Duration _notificationDebounceWindow = Duration(minutes: 2);

  // Navigation guard: prevents stacking multiple full-screen routes for the same order
  String? _activeFullScreenOrderId;

  // Synchronous lock: blocks concurrent async paths from both pushing full-screen.
  // Set BEFORE any await in _showFullScreenNotification, cleared in clearActiveFullScreen.
  bool _isNavigatingToFullScreen = false;

  // ── Offer-level deduplication (central gate) ──
  // Map<offerId, timestamp> with 10-minute TTL. Prevents both FcmForegroundBridge
  // and FirebaseMessaging.onMessage from triggering UI for the same message.
  // Entries auto-expire so memory stays bounded without arbitrary size caps.
  final Map<String, DateTime> _seenOfferIds = {};
  static const Duration _offerTtl = Duration(minutes: 10);

  // Lock: if an offerId is currently being processed, the second caller awaits
  // and then returns (no-op). Prevents race conditions where two async calls
  // both pass the _seenOfferIds check before either writes to it.
  final Map<String, Completer<void>> _processingOffers = {};

  // Replay protection key for SharedPreferences (survives app restart).
  static const String _kLastOfferId = 'last_handled_offer_id';

  // Cache for active notification data (survives GoRouter rebuilds)
  FullScreenNotificationData? _cachedFullScreenData;
  TripStartReminderData? _cachedTripReminderData;

  // Persistent dedup service (initialized via initDedup)
  NotificationDedupService? _dedupService;

  Future<void> initialize() async {
    _navigatorKey = appNavigatorKey;

    // PATCH-01: Reset the navigation guard on every app start.
    // The singleton survives Dart isolate restarts on some devices; without
    // this reset, _activeFullScreenOrderId left over from the previous session
    // blocks every subsequent full-screen notification permanently.
    _activeFullScreenOrderId = null;
    _isNavigatingToFullScreen = false;

    await _initializeLocalNotifications();
    await _setupFirebaseMessaging();
  }

  /// Inject the persistent dedup service (call after SharedPreferences is ready).
  void initDedup(NotificationDedupService dedupService) {
    _dedupService = dedupService;
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
  /// v10 channels (with bypassDnd + USAGE_ALARM) are created via Native Kotlin
  /// through NotificationMethodChannel. These handle all order/reminder notifications.
  ///
  /// flutter_local_notifications is only used for non-critical notifications
  /// (acceptance_confirmation, order_updates) which use the default channel.
  Future<void> _createNotificationChannels() async {
    // v10 channels via Native Kotlin (bypassDnd, full-screen intent, USAGE_ALARM)
    try {
      await NotificationMethodChannel.createNotificationChannels();
      if (kDebugMode) {
        debugPrint('[NotificationService] ✅ Native v10 channels created');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationService] ⚠️ Native channel creation failed: $e');
      }
    }

    // Clean up ALL legacy channels (v1-v9). Native Kotlin creates v10 channels.
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
        'new_orders_v7',
        'new_orders_v8',
        'new_orders_v9',
        'unassigned_orders',
        'unassigned_orders_v2',
        'unassigned_orders_v3',
        'unassigned_orders_v4',
        'unassigned_orders_v5',
        'unassigned_orders_v6',
        'unassigned_orders_v7',
        'unassigned_orders_v8',
        'unassigned_orders_v9',
        'trip_reminders',
        'trip_reminders_v2',
        'trip_reminders_v3',
        'trip_reminders_v4',
        'trip_reminders_v5',
        'trip_reminders_v6',
        'trip_reminders_v7',
        'trip_reminders_v8',
        'trip_reminders_v9',
        'order_updates',
        'order_updates_v1',
        'acceptance_confirmations',
        'acceptance_confirmations_v1',
      ]) {
        await android.deleteNotificationChannel(id);
      }
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    // Both listeners funnel through handleIncomingOffer for dedup.
    // Fallback: firebase_messaging onMessage (may not fire if native intercepts).
    FirebaseMessaging.onMessage.listen((msg) {
      if (kDebugMode) debugPrint('[NotificationService] ← FirebaseMessaging.onMessage');
      handleIncomingOffer(msg.data, source: 'onMessage');
    });

    // Primary foreground path: FcmForegroundBridge (Kotlin EventChannel).
    NotificationMethodChannel.onForegroundMessage.listen((data) {
      if (kDebugMode) debugPrint('[NotificationService] ← FcmForegroundBridge');
      handleIncomingOffer(data, source: 'bridge');
    });

    // Native action intents (accept/reject from FullScreenNotificationActivity
    // or OrderActionReceiver). Delivered via EventChannel from MainActivity.
    NotificationMethodChannel.onNewIntent.listen(_handleNativeActionIntent);

    // PART 2: Tap routing — background (app was in background, user taps)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTapFromFCM);

    // PART 2: Tap routing — killed state is handled in processInitialMessage(),
    // called from main.dart AFTER initDedup() so replay protection is available.
  }

  /// Process the FCM initial message (cold-start tap).
  ///
  /// PATCH-04 (RC-15): Separated from _setupFirebaseMessaging() so that it is
  /// called only after initDedup() has been called, ensuring _dedupService is
  /// non-null when the replay check runs. Call this from main.dart immediately
  /// after NotificationService().initDedup(...).
  Future<void> processInitialMessage() async {
    // ── Fallback: check SharedPreferences cache for native action intents ──
    // If the app was killed and FullScreenNotificationActivity launched
    // MainActivity with accept/reject, the EventChannel sink was null.
    // MainActivity cached the intent to SharedPreferences as fallback.
    final cachedAction = await NotificationMethodChannel.getPendingActionFromCache();
    if (cachedAction != null && cachedAction['action'] != null) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] 📦 Recovered cached native action: ${cachedAction['action']}',
        );
      }
      await NotificationMethodChannel.clearPendingActionCache();
      _handleNativeActionIntent(cachedAction);
      return; // Don't also process FCM initial message (same tap)
    }

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // ── Replay protection for cold-start ──
      final initOfferKey = _extractOfferKey(initialMessage.data);
      if (initOfferKey.isNotEmpty && await _isReplayedOffer(initOfferKey)) {
        if (kDebugMode) {
          debugPrint(
            '[NotificationService] ⛔ initialMessage REPLAY blocked: $initOfferKey',
          );
        }
      } else {
        _handleNotificationTapFromFCM(initialMessage);
      }
    }
  }



  /// Handle notification tap from FCM (background or killed state).
  /// Routes to the correct screen based on notification type and orderId.
  void _handleNotificationTapFromFCM(RemoteMessage message) {
    final data = message.data;
    final type = NotificationHelper.resolveType(data);
    final orderId = data['orderId'] as String?;

    if (kDebugMode) {
      debugPrint(
        '[NotificationService] Notification tapped → routing: '
        'type=$type, orderId=$orderId',
      );
    }

    NotificationLogger.instance.log(
      eventType: 'tapped',
      notificationType: type ?? 'unknown',
      appState: 'background',
      orderId: orderId,
    );

    // Cancel sound repeats for this order
    if (orderId != null) {
      NotificationMethodChannel.cancelSoundRepeats(orderId);
    }

    // ── Dedup: don't re-show offer if already handled ──
    if (orderId != null && _isStaleNotification(orderId)) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] ⛔ Tap blocked — order $orderId already processed',
        );
      }
      return;
    }
    final offerKey = _extractOfferKey(data);
    if (offerKey.isNotEmpty && _isSeenOffer(offerKey)) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] ⛔ Tap blocked — offer $offerKey already seen',
        );
      }
      // Still navigate to home so user isn't stuck
      _navigateTo('/');
      return;
    }

    _navigateFromMessage(data);
  }

  /// Handle action intents from native FullScreenNotificationActivity / OrderActionReceiver.
  /// Delivered via EventChannel (onNewIntent) or SharedPreferences fallback cache.
  void _handleNativeActionIntent(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    final orderId = data['orderId'] as String?;

    if (kDebugMode) {
      debugPrint(
        '[NotificationService] ← Native action intent: action=$action, orderId=$orderId',
      );
    }

    if (action == null || orderId == null) return;

    NotificationLogger.instance.log(
      eventType: 'native_action',
      notificationType: data['notificationType'] as String? ?? action,
      appState: 'native_intent',
      orderId: orderId,
    );

    switch (action) {
      case 'accept_order':
        _handleNativeAccept(orderId, data['offerId'] as String?);
        break;
      case 'reject_order':
        markOrderAsProcessed(orderId);
        _navigateTo('/');
        break;
      case 'start_trip':
        _navigateTo('/active-order');
        break;
      default:
        _navigateFromMessage(data);
    }
  }

  /// Execute the actual accept call when the native Intent arrives.
  Future<void> _handleNativeAccept(String orderId, String? offerId) async {
    try {
      final ordersService = OrdersService();
      if (offerId != null && offerId.isNotEmpty) {
        await ordersService.acceptOfferV2(offerId: offerId, orderId: orderId);
      } else {
        await ordersService.acceptOrder(orderId);
      }
      markOrderAsProcessed(orderId);
      _navigateTo('/active-order');
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] ❌ Native accept failed: $e');
      }
      _navigateTo('/');
    }
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
  // Offer-level dedup helpers
  // ---------------------------------------------------------------------------

  /// Build a collision-safe dedup key.
  /// Uses `offerId` when present (globally unique from Cloud Functions).
  /// Falls back to `orderId_round` to distinguish waves for the same order.
  static String _extractOfferKey(Map<String, dynamic> data) {
    final explicit = data['offerId'] as String?;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final orderId = data['orderId'] as String? ?? '';
    final round = data['round'] as String? ?? '1';
    return '${orderId}_$round';
  }

  /// Returns true if [offerId] was already seen and its TTL has not expired.
  /// Expired entries are removed lazily so they can be re-processed.
  bool _isSeenOffer(String offerId) {
    final ts = _seenOfferIds[offerId];
    if (ts == null) return false;
    if (DateTime.now().difference(ts) >= _offerTtl) {
      _seenOfferIds.remove(offerId); // expired → allow
      return false;
    }
    return true;
  }

  /// Lightweight TTL sweep — removes all entries older than [_offerTtl].
  /// Called on every incoming message; O(n) but n is tiny (< 50 in practice).
  void _pruneExpiredOffers() {
    final now = DateTime.now();
    _seenOfferIds.removeWhere((_, ts) => now.difference(ts) >= _offerTtl);
  }

  /// Persist [offerId] to SharedPreferences so a restart cannot replay it.
  /// Fire-and-forget — never blocks the notification pipeline.
  void _persistLastOfferId(String offerId) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kLastOfferId, offerId);
    }).catchError((_) {/* storage failure is non-fatal */});
  }

  /// Check if [offerId] matches the last persisted offer (replay protection).
  Future<bool> _isReplayedOffer(String offerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kLastOfferId) == offerId;
    } catch (_) {
      return false; // storage failure → fail-open
    }
  }

  // ---------------------------------------------------------------------------
  // Central entry point — ALL foreground paths MUST call this
  // ---------------------------------------------------------------------------

  /// Central handler for every incoming offer / notification.
  ///
  /// Dedup pipeline (in order):
  /// 1. Extract wave-safe offerId key
  /// 2. TTL prune (lightweight, every call)
  /// 3. Replay check (SharedPreferences — survives restart)
  /// 4. In-memory TTL dedup (_seenOfferIds)
  /// 5. Completer-based race lock
  /// 6. Process → mark seen (memory + disk)
  ///
  /// [source] is for logging only ('onMessage' | 'bridge' | 'recovery').
  Future<void> handleIncomingOffer(
    Map<String, dynamic> data, {
    String source = 'unknown',
  }) async {
    final offerId = _extractOfferKey(data);

    // ── 1. TTL prune (cheap, keeps map small) ──
    _pruneExpiredOffers();

    // ── 2. In-memory TTL dedup (synchronous — must run before any await) ──
    // PATCH-12 (RC-04): Previously the async _isReplayedOffer ran first, leaving
    // a ~5ms window where a second concurrent caller could pass this check before
    // the first call had written to _seenOfferIds. Synchronous check is now first.
    if (offerId.isNotEmpty && _isSeenOffer(offerId)) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] ⛔ DUPLICATE blocked (offerId=$offerId, source=$source)',
        );
      }
      NotificationLogger.instance.log(
        eventType: 'duplicate_blocked',
        notificationType: NotificationHelper.resolveType(data) ?? 'unknown',
        appState: 'foreground',
        orderId: data['orderId'] as String?,
        escalationLevel: 'dedup_$source',
      );
      return;
    }

    // ── 3. Race-condition lock (synchronous) ──
    if (offerId.isNotEmpty && _processingOffers.containsKey(offerId)) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] ⏳ RACE blocked — waiting on offerId=$offerId (source=$source)',
        );
      }
      await _processingOffers[offerId]!.future;
      return;
    }

    // ── 4. Stamp in-memory BEFORE any await so concurrent callers are blocked ──
    if (offerId.isNotEmpty) {
      _seenOfferIds[offerId] = DateTime.now();
    }

    // ── 5. Replay protection (async — SharedPrefs survives app restart) ──
    if (offerId.isNotEmpty && await _isReplayedOffer(offerId)) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] ⛔ REPLAY blocked (offerId=$offerId, source=$source)',
        );
      }
      NotificationLogger.instance.log(
        eventType: 'duplicate_blocked',
        notificationType: NotificationHelper.resolveType(data) ?? 'unknown',
        appState: 'foreground',
        orderId: data['orderId'] as String?,
        escalationLevel: 'replay_$source',
      );
      // Remove the pre-stamp so a future legitimate delivery is not also blocked.
      _seenOfferIds.remove(offerId);
      return;
    }

    // ── 6. Acquire Completer lock ──
    final completer = Completer<void>();
    if (offerId.isNotEmpty) _processingOffers[offerId] = completer;

    try {
      // ── 5b. Acceptance-lock guard (PATCH-10 / RC-05) ──
      // If the driver tapped Accept <5s ago, suppress incoming offers until the
      // server confirms. Without this the lock existed but was never consulted.
      if (await AcceptanceLockManager.isWithinAcceptanceWindow()) {
        if (kDebugMode) {
          debugPrint(
            '[NotificationService] ⛔ Acceptance lock active — suppressing offer (source=$source)',
          );
        }
        return;
      }

      // Mark as seen immediately (before any async gap).
      if (offerId.isNotEmpty) {
        _seenOfferIds[offerId] = DateTime.now();
        _persistLastOfferId(offerId);
      }

      await _handleForegroundMessageInner(data);
    } finally {
      // ── Release lock ──
      if (offerId.isNotEmpty) _processingOffers.remove(offerId);
      if (!completer.isCompleted) completer.complete();
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground message handler (inner — only called from handleIncomingOffer)
  // ---------------------------------------------------------------------------

  Future<void> _handleForegroundMessageInner(Map<String, dynamic> data) async {
    final notificationType = NotificationHelper.resolveType(data);
    final orderId = data['orderId'] as String?;
    // FcmForegroundBridge messages never carry a notification block.
    const hasSystemNotification = false;

    // ── Persistent dedup check ──
    // PATCH-02: Use the wave-stable offerId key (same key used by _seenOfferIds),
    // NOT messageId which contained Date.now() and was always unique.
    final persistDedupKey = _extractOfferKey(data);
    if (persistDedupKey.isNotEmpty && _dedupService != null) {
      if (_dedupService!.isDuplicate(persistDedupKey)) {
        NotificationLogger.instance.log(
          eventType: 'skipped',
          notificationType: notificationType ?? 'unknown',
          appState: 'foreground',
          orderId: orderId,
          escalationLevel: 'persistent_duplicate',
        );
        return;
      }
      _dedupService!.markAsProcessed(persistDedupKey);
    }

    if (kDebugMode) {
      debugPrint(
        '[NotificationService] 🔔 onMessage: type=$notificationType, '
        'orderId=$orderId, hasSystemNotification=$hasSystemNotification',
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

      // Filter stale notifications for recently accepted/rejected orders
      if (orderId != null && _isStaleNotification(orderId)) {
        NotificationLogger.instance.log(
          eventType: 'skipped',
          notificationType: notificationType ?? 'unknown',
          appState: 'foreground',
          orderId: orderId,
          escalationLevel: 'stale_notification',
        );
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

    // ── Other notification types → standard local notification ──
    // DUPLICATE PROTECTION: If the FCM message already has a notification block,
    // Android displayed it in the system tray. Don't show a second local one.
    if (hasSystemNotification) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] Skipping local notification (system handled) '
          'type=$notificationType, orderId=$orderId',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[NotificationService] Showing local notification (data-only fallback) '
        'type=$notificationType, orderId=$orderId',
      );
    }

    final title = (data['title'] as String?) ?? _defaultTitle(notificationType);
    final body = (data['body'] as String?) ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final payload = jsonEncode(data);
    final notificationId = orderId?.hashCode ?? payload.hashCode;

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

    // Guard: verify order is still 'accepted' before showing reminder
    if (orderId.isNotEmpty) {
      final stillAccepted = await _isOrderStillAccepted(orderId);
      if (!stillAccepted) {
        if (kDebugMode) {
          debugPrint(
            '[NotificationService] ⛔ Trip reminder dropped — order $orderId no longer accepted',
          );
        }
        NotificationLogger.instance.log(
          eventType: 'skipped',
          notificationType: 'trip_start_reminder',
          appState: 'foreground',
          orderId: orderId,
          escalationLevel: 'order_not_accepted',
        );
        return;
      }
    }

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

  /// Check if order is still in 'accepted' status (for trip_start_reminder guard).
  Future<bool> _isOrderStillAccepted(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get(const GetOptions(source: Source.server));
      return doc.exists && doc.data()?['status'] == 'accepted';
    } on Object catch (_) {
      // PATCH-09 (RC-06): Fail-closed. If we cannot reach the server we must
      // not show a reminder — the order may have been cancelled or completed.
      return false;
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

    // Apply debouncing to prevent duplicate notifications
    // Use offerId (unique per wave) instead of orderId to allow wave 2/3
    // to show full-screen even if wave 1 was shown recently.
    final dedupeKey = data['offerId'] as String? ?? notificationData.orderId;
    if (_isDuplicateNotification(dedupeKey)) {
      NotificationLogger.instance.log(
        eventType: 'skipped',
        notificationType: NotificationHelper.resolveType(data) ?? 'unknown',
        appState: 'foreground',
        orderId: notificationData.orderId,
        escalationLevel: 'duplicate_notification',
      );
      return;
    }

    // Navigation guard: prevent stacking full-screen routes.
    // Synchronous lock check FIRST (before any await in the caller path).
    if (_isNavigatingToFullScreen) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] ⛔ Navigation lock active — skipping ${notificationData.orderId}',
        );
      }
      NotificationLogger.instance.log(
        eventType: 'skipped',
        notificationType: NotificationHelper.resolveType(data) ?? 'unknown',
        appState: 'foreground',
        orderId: notificationData.orderId,
        escalationLevel: 'navigation_lock',
      );
      return;
    }

    // Block ANY new full-screen if one is already active (even for a different order).
    if (_activeFullScreenOrderId != null) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] ⛔ Full-screen already active for order: $_activeFullScreenOrderId — skipping ${notificationData.orderId}',
        );
      }
      NotificationLogger.instance.log(
        eventType: 'skipped',
        notificationType: NotificationHelper.resolveType(data) ?? 'unknown',
        appState: 'foreground',
        orderId: notificationData.orderId,
        escalationLevel: 'another_fullscreen_active',
      );
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[NotificationService] 🚀 Full-screen notification for order: ${notificationData.orderId}',
      );
    }

    final type = NotificationHelper.resolveType(data);

    // Mark notification as shown (for debouncing) and set navigation guard
    _markNotificationShown(dedupeKey);
    _isNavigatingToFullScreen = true;
    _activeFullScreenOrderId = notificationData.orderId;

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
      cacheFullScreenNotification(data);
      ctx.go('/full-screen-notification', extra: data);
      // Lock remains active — cleared by clearActiveFullScreen() on dismiss
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] ❌ Navigation error: $e');
      }
      // Release lock on failure so next notification can proceed
      _isNavigatingToFullScreen = false;
      _activeFullScreenOrderId = null;
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
      cacheTripReminderNotification(data);
      ctx.go('/trip-start-reminder', extra: data);
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
      // Release navigation lock to prevent permanent deadlock
      _isNavigatingToFullScreen = false;
      _activeFullScreenOrderId = null;
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

    if (route != null) {
      if (_navigatorKey?.currentContext != null) {
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
        // Save pending route if context not ready
        _pendingRoute = route;
        _schedulePendingNavigation(() {
          if (_navigatorKey?.currentContext != null) {
            _navigatorKey!.currentContext!.go(route);
          }
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Clear the navigation guard when the full-screen notification is dismissed.
  /// Must be called from accept / reject / snooze / dispose in FullScreenNotificationScreen.
  void clearActiveFullScreen() {
    _activeFullScreenOrderId = null;
    _isNavigatingToFullScreen = false;
  }

  /// Remove a specific offer from ALL dedup layers so it can be re-shown
  /// after a snooze alarm fires. Only call this from the snooze handler.
  void clearSnoozedOffer(String offerKey) {
    if (offerKey.isEmpty) return;
    _seenOfferIds.remove(offerKey);
    _recentlyShownNotifications.remove(offerKey);
    _dedupService?.clearProcessed(offerKey);
    if (kDebugMode) {
      debugPrint('[NotificationService] 🔕 Dedup cleared for snoozed offer: $offerKey');
    }
  }

  /// Mark order as recently processed (accepted/rejected) to filter stale notifications.
  void markOrderAsProcessed(String orderId) {
    _recentlyProcessedOrders[orderId] = DateTime.now();
    // Cleanup old entries (older than 5 minutes)
    _recentlyProcessedOrders.removeWhere(
      (key, timestamp) => DateTime.now().difference(timestamp) > const Duration(minutes: 5),
    );
    // Note: we do NOT clear _seenOfferIds here — an already-shown offer
    // should never be shown again even after the driver processes the order.
  }

  /// Check if this is a stale notification for a recently processed order.
  bool _isStaleNotification(String orderId) {
    final processedAt = _recentlyProcessedOrders[orderId];
    if (processedAt == null) return false;
    final elapsed = DateTime.now().difference(processedAt);
    final isStale = elapsed < _staleNotificationWindow;
    if (isStale && kDebugMode) {
      debugPrint(
        '[NotificationService] Filtering stale notification for order $orderId (processed ${elapsed.inSeconds}s ago)',
      );
    }
    return isStale;
  }

  /// Check if this notification was recently shown (debouncing).
  bool _isDuplicateNotification(String orderId) {
    final shownAt = _recentlyShownNotifications[orderId];
    if (shownAt == null) return false;
    final elapsed = DateTime.now().difference(shownAt);
    final isDuplicate = elapsed < _notificationDebounceWindow;
    if (isDuplicate && kDebugMode) {
      debugPrint(
        '[NotificationService] Filtering duplicate notification for order $orderId (shown ${elapsed.inSeconds}s ago)',
      );
    }
    return isDuplicate;
  }

  /// Mark notification as shown (for debouncing).
  void _markNotificationShown(String orderId) {
    _recentlyShownNotifications[orderId] = DateTime.now();
    // Cleanup old entries (older than 1 minute)
    _recentlyShownNotifications.removeWhere(
      (key, timestamp) => DateTime.now().difference(timestamp) > const Duration(minutes: 1),
    );
  }

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

  /// Cache the active full-screen notification data to survive GoRouter rebuilds.
  void cacheFullScreenNotification(FullScreenNotificationData data) {
    _cachedFullScreenData = data;
  }

  /// Get cached full-screen notification data.
  FullScreenNotificationData? getCachedFullScreenNotification() {
    return _cachedFullScreenData;
  }

  /// Clear cached full-screen notification (call when user dismisses/exits screen).
  void clearCachedFullScreenNotification() {
    _cachedFullScreenData = null;
  }

  /// Cache the active trip reminder data to survive GoRouter rebuilds.
  void cacheTripReminderNotification(TripStartReminderData data) {
    _cachedTripReminderData = data;
  }

  /// Get cached trip reminder data.
  TripStartReminderData? getCachedTripReminderNotification() {
    return _cachedTripReminderData;
  }

  /// Clear cached trip reminder.
  void clearCachedTripReminderNotification() {
    _cachedTripReminderData = null;
  }

  /// Called by MissedNotificationRecovery to display a recovered notification.
  /// Funnels through the central dedup gate.
  void recoverNotification(Map<String, dynamic> data) {
    handleIncomingOffer(data, source: 'recovery');
  }
}
