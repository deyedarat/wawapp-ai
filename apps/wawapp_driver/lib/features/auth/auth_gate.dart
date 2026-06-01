import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/testlab_flags.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';
import '../../services/notification_method_channel.dart';
import '../../services/notification_service.dart';
import '../../services/notification_system_initializer.dart';
import '../notifications/trip_start_reminder_screen.dart';
import '../../services/orders_service.dart';
import '../../testlab/testlab_home.dart';
import 'providers/auth_service_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _lastInitializedUserId;
  StreamSubscription<Map<String, dynamic>>? _intentSubscription;

  void _initializeServicesOnce(String userId, BuildContext context) {
    if (_lastInitializedUserId == userId) {
      return; // Already initialized for this user
    }

    // We no longer have direct access to firestore data here
    // Properties will be set when profile is loaded in specific screens if needed
    AnalyticsService.instance.setUserProperties(
      userId: userId,
      // totalTrips, rating, etc. removed as we don't fetch doc here anymore
      // logic for these specific properties should move to where profile is actually fetched
    );
    AnalyticsService.instance.logAuthCompleted(method: 'phone_pin');
    FCMService.instance.initialize(context);

    // Initialize production-grade notification system
    NotificationSystemInitializer.initializeAfterLogin();

    _lastInitializedUserId = userId;

    _processPendingIntentAccept();

    _intentSubscription?.cancel();
    _intentSubscription = NotificationMethodChannel.onNewIntent.listen((data) {
      if (mounted) _processLiveIntent(data);
    });
  }

  Future<void> _processPendingIntentAccept() async {
    final intentData = await NotificationMethodChannel.getIntentData();
    if (!mounted) return;
    if (intentData == null) return;

    final action = intentData['action'];
    final orderId = intentData['orderId'];
    final offerId = intentData['offerId'];
    if (action == null || orderId == null || orderId.isEmpty) return;

    await NotificationMethodChannel.clearIntentData();
    if (!mounted) return;

    switch (action) {
      case 'accept_order':
        await _handleNativeAccept(orderId, offerId: offerId);
      case 'view_order':
        _navigateToOrderDetails();
      case 'reject_order':
        await _handleNativeReject(orderId);
      case 'snooze_order':
        _handleNativeSnooze();
      case 'trip_start_reminder':
        _handleNativeTripReminder(intentData);
      case 'start_trip':
        await _handleNativeStartTrip(orderId);
    }
  }

  Future<void> _handleNativeAccept(String orderId, {String? offerId}) async {
    try {
      if (offerId != null && offerId.isNotEmpty) {
        await ref.read(ordersServiceProvider).acceptOfferV2(offerId: offerId, orderId: orderId);
        // Server confirmed — now safe to suppress the offer
        NotificationService().handleIncomingOffer({
          'orderId': orderId,
          'offerId': offerId,
        }, source: 'native_accept_suppress');
      } else {
        await ref.read(ordersServiceProvider).acceptOrder(orderId, '');
      }
      // Server confirmed — now safe to suppress locally.
      NotificationService().markOrderAsProcessed(orderId);
      NotificationService().clearActiveFullScreen();
      if (mounted) context.go('/active-order');
    } on Object catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('already taken') || e.toString().contains('failed-precondition')
          ? 'تم أخذ الطلب بالفعل'
          : 'تعذّر قبول الطلب، حاول مرة أخرى';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE53935)));
    }
  }

  Future<void> _handleNativeStartTrip(String orderId) async {
    try {
      await ref.read(ordersServiceProvider).transition(orderId, OrderStatus.onRoute);
      if (mounted) context.go('/active-order');
    } on Object catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('Invalid status') ? 'الرحلة بدأت بالفعل' : 'تعذّر بدء الرحلة، حاول مرة أخرى';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE53935)));
    }
  }

  void _navigateToOrderDetails() {
    if (mounted) context.go('/');
  }

  void _processLiveIntent(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    final orderId = data['orderId'] as String? ?? '';
    final offerId = data['offerId'] as String?;
    if (action == null || orderId.isEmpty) return;
    switch (action) {
      case 'accept_order':
        _handleNativeAccept(orderId, offerId: offerId);
      case 'reject_order':
        _handleNativeReject(orderId);
      case 'view_order':
        _navigateToOrderDetails();
      case 'start_trip':
        _handleNativeStartTrip(orderId);
    }
  }

  Future<void> _handleNativeReject(String orderId) async {
    NotificationService().markOrderAsProcessed(orderId);
    NotificationService().clearActiveFullScreen();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('driver_rejected_orders').add({
          'driverId': uid,
          'orderId': orderId,
          'rejectedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
        });
        if (kDebugMode) {
          debugPrint('[AuthGate] Order $orderId rejected from native activity');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[AuthGate] Failed to write rejection: $e');
      }
    }
    if (mounted) context.go('/');
  }

  void _handleNativeSnooze() {
    // Backend will re-notify via unassigned_order_reminder FCM after its own timeout.
    // No local timer needed here since the app was just cold-started.
    if (mounted) context.go('/');
  }

  void _handleNativeTripReminder(Map<String, String?> data) {
    // Handled by native TripReminderActivity — no Flutter navigation needed
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    _intentSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check Test Lab mode first - bypass all logic
    if (TestLabFlags.safeEnabled) {
      debugPrint('[AuthGate] REDIRECT_REASON=TEST_LAB_MODE → TestLabHome');
      return const TestLabHome();
    }

    final authState = ref.watch(authProvider);

    // One-time service initialization when user is present
    final user = authState.user;
    if (user != null) {
      // Defer to next frame to ensure safe context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeServicesOnce(user.uid, context);
        }
      });
    }

    // Passive wrapper: checking auth, pin, etc. is now done by AppRouter
    return widget.child;
  }
}
