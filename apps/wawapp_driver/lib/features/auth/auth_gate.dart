import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/testlab_flags.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';
import '../../services/notification_method_channel.dart';
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

    // Process pending accept action from native notification (lock screen accept button).
    // FullScreenNotificationActivity.onAcceptClicked() stores the orderId in Intent extras
    // but Flutter never called getIntentData() — this is the fix.
    _processPendingIntentAccept(context);
  }

  Future<void> _processPendingIntentAccept(BuildContext context) async {
    final intentData = await NotificationMethodChannel.getIntentData();
    if (intentData == null) return;

    final action = intentData['action'];
    final orderId = intentData['orderId'];
    if (action == null || orderId == null || orderId.isEmpty) return;

    await NotificationMethodChannel.clearIntentData();

    switch (action) {
      case 'open_order':
        await _handleNativeAccept(context, orderId);
      case 'reject_order':
        await _handleNativeReject(context, orderId);
      case 'snooze_order':
        _handleNativeSnooze(context);
      case 'trip_start_reminder':
        _handleNativeTripReminder(context, intentData);
    }
  }

  Future<void> _handleNativeAccept(BuildContext context, String orderId) async {
    try {
      await ref.read(ordersServiceProvider).acceptOrder(orderId);
      if (mounted && context.mounted) context.go('/active-order');
    } on Object catch (e) {
      if (!mounted || !context.mounted) return;
      final msg = e.toString().contains('already taken') || e.toString().contains('failed-precondition')
          ? 'تم أخذ الطلب بالفعل'
          : 'تعذّر قبول الطلب، حاول مرة أخرى';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }

  Future<void> _handleNativeReject(BuildContext context, String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('driver_rejected_orders')
            .add({
          'driverId': uid,
          'orderId': orderId,
          'rejectedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24)),
          ),
        });
        if (kDebugMode) {
          debugPrint('[AuthGate] Order $orderId rejected from native activity');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[AuthGate] Failed to write rejection: $e');
      }
    }
    if (mounted && context.mounted) context.go('/');
  }

  void _handleNativeSnooze(BuildContext context) {
    // Backend will re-notify via unassigned_order_reminder FCM after its own timeout.
    // No local timer needed here since the app was just cold-started.
    if (mounted && context.mounted) context.go('/');
  }

  void _handleNativeTripReminder(BuildContext context, Map<String, String?> data) {
    if (!mounted || !context.mounted) return;
    final reminderData = TripStartReminderData.tryParse(data);
    if (reminderData != null) {
      context.push('/trip-start-reminder', extra: reminderData);
    } else {
      context.go('/active-order');
    }
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
