import 'dart:async';

import 'package:auth_shared/auth_shared.dart';
import 'package:core_shared/core_shared.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/active/active_order_screen.dart';
import '../../features/auth/auth_gate.dart';
import '../../features/auth/create_pin_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/phone_pin_login_screen.dart';
import '../../features/auth/providers/auth_service_provider.dart';
import '../../features/auth/screens/driver_blocked_screen.dart';
import '../../features/auth/screens/pin_gate_screen.dart';
import '../../features/earnings/driver_earnings_screen.dart';
import '../../features/history/driver_history_screen.dart';
import '../../features/history/order_details_screen.dart';
import '../../features/home/driver_home_screen.dart';
import '../../features/nearby/nearby_screen.dart';
import '../../features/profile/driver_profile_edit_screen.dart';
import '../../features/notifications/full_screen_notification_screen.dart';
import '../../features/notifications/trip_start_reminder_screen.dart';
import '../../features/profile/driver_profile_screen.dart';
import '../../features/settings/notification_health_screen.dart';
import '../../features/profile/providers/driver_profile_providers.dart';
import '../../features/wallet/wallet_screen.dart';
import '../../services/notification_service.dart';
import 'navigator.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Use ref.listen (not ref.watch) so this provider is never recreated when
  // auth/profile changes — only redirect() is re-evaluated via refreshListenable.
  final refreshNotifier = _RouterRefreshNotifier();

  ref.listen<AuthState>(authProvider, (_, __) => refreshNotifier.notify());
  ref.listen(driverProfileStreamProvider, (_, __) => refreshNotifier.notify());

  final router = GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      // Read current values at redirect time (not captured in closure)
      // so the redirect always uses fresh state without recreating the router.
      final authState = ref.read(authProvider);
      final driverProfile = ref.read(driverProfileStreamProvider).valueOrNull;
      return _redirect(state, authState, driverProfile);
    },
    refreshListenable: refreshNotifier,
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const AuthGate(child: DriverHomeScreen()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const PhonePinLoginScreen(),
      ),
      GoRoute(
        path: '/nearby',
        name: 'nearby',
        builder: (context, state) => const NearbyScreen(),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/otp',
        name: 'otp',
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: '/create-pin',
        name: 'createPin',
        builder: (context, state) => const CreatePinScreen(),
      ),
      GoRoute(
        path: '/pin-gate',
        name: 'pinGate',
        builder: (context, state) => const PinGateScreen(),
      ),
      GoRoute(
        path: '/blocked',
        name: 'blocked',
        builder: (context, state) => const DriverBlockedScreen(),
      ),
      GoRoute(
        path: '/active-order',
        name: 'activeOrder',
        builder: (context, state) => const ActiveOrderScreen(),
      ),
      GoRoute(
        path: '/earnings',
        name: 'earnings',
        builder: (context, state) => const DriverEarningsScreen(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const DriverHistoryScreen(),
      ),
      GoRoute(
        path: '/order-details',
        name: 'orderDetails',
        builder: (context, state) {
          final order = state.extra as Order;
          return OrderDetailsScreen(order: order);
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const DriverProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'profileEdit',
        builder: (context, state) => const DriverProfileEditScreen(),
      ),
      GoRoute(
        path: '/full-screen-notification',
        name: 'fullScreenNotification',
        builder: (context, state) {
          // 1. Try GoRouter extra (in-app navigation)
          final extra = state.extra;
          if (extra is FullScreenNotificationData) {
            // Cache on first build to survive GoRouter refreshes
            NotificationService().cacheFullScreenNotification(extra);
            return FullScreenNotificationScreen(data: extra);
          }

          // 2. Retrieve from cache on rebuild (when extra is lost)
          final cached =
              NotificationService().getCachedFullScreenNotification();
          if (cached != null) {
            return FullScreenNotificationScreen(data: cached);
          }

          // 3. Last resort: try query parameters (deep links)
          final params = state.uri.queryParameters;
          final data = FullScreenNotificationData.tryParse(params);
          if (data != null) {
            NotificationService().cacheFullScreenNotification(data);
            return FullScreenNotificationScreen(data: data);
          }

          // 4. Fallback — missing or invalid data
          if (kDebugMode) {
            debugPrint('[ROUTER] ❌ /full-screen-notification: invalid params, '
                'extra=$extra, query=$params');
          }
          return const NearbyScreen();
        },
      ),
      GoRoute(
        path: '/trip-start-reminder',
        name: 'tripStartReminder',
        builder: (context, state) {
          // 1. Try GoRouter extra (in-app navigation)
          final extra = state.extra;
          if (extra is TripStartReminderData) {
            // Cache on first build to survive GoRouter refreshes
            NotificationService().cacheTripReminderNotification(extra);
            return TripStartReminderScreen(data: extra);
          }

          // 2. Retrieve from cache on rebuild (when extra is lost)
          final cached =
              NotificationService().getCachedTripReminderNotification();
          if (cached != null) {
            return TripStartReminderScreen(data: cached);
          }

          // 3. Last resort: try query parameters (deep links)
          final params = state.uri.queryParameters;
          final data = TripStartReminderData.tryParse(params);
          if (data != null) {
            NotificationService().cacheTripReminderNotification(data);
            return TripStartReminderScreen(data: data);
          }

          // 4. Fallback — missing or invalid data, redirect to active order
          if (kDebugMode) {
            debugPrint('[ROUTER] ❌ /trip-start-reminder: invalid params, '
                'extra=$extra, query=$params');
          }
          return const ActiveOrderScreen();
        },
      ),
      GoRoute(
        path: '/notification-health',
        name: 'notificationHealth',
        builder: (context, state) => const NotificationHealthScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });

  return router;
});

String? _redirect(GoRouterState s, AuthState st, DriverProfile? profile) {
  final loggedIn = st.user != null;
  final canOtp = st.otpFlowActive ||
      st.otpStage == OtpStage.sending ||
      st.otpStage == OtpStage.codeSent;

  if (kDebugMode) {
    debugPrint('[ROUTER] Navigation check | '
        'location=${s.matchedLocation} | '
        'user=${st.user?.uid ?? 'null'} | '
        'pinStatus=${st.pinStatus} | '
        'canOtp=$canOtp | '
        'isPinResetFlow=${st.isPinResetFlow}');
  }

  // 1. OTP FLOW: User is in OTP verification process
  // Priority: Highest (must override all other checks)
  if (canOtp) {
    if (s.matchedLocation != '/otp') {
      if (kDebugMode) {
        debugPrint(
            '[ROUTER] → Redirect to /otp (OTP flow active, otpStage=${st.otpStage})');
      }
      return '/otp';
    }
    if (kDebugMode) {
      debugPrint('[ROUTER] ✓ Already on /otp (staying)');
    }
    return null;
  }

  // 2. NOT AUTHENTICATED: No user
  if (!loggedIn) {
    if (s.matchedLocation != '/login') {
      if (kDebugMode) {
        debugPrint('[ROUTER] → Redirect to /login (not authenticated)');
      }
      return '/login';
    }
    if (kDebugMode) {
      debugPrint('[ROUTER] ✓ Already on /login');
    }
    return null;
  }

  // 3. AUTHENTICATED BUT PIN STATUS UNKNOWN/LOADING/ERROR
  // Redirect to PinGateScreen to wait for check or retry
  if (st.pinStatus == PinStatus.unknown ||
      st.pinStatus == PinStatus.loading ||
      st.pinStatus == PinStatus.error) {
    // Notification screens are allowed through even while PIN status is resolving.
    // The user is already authenticated (loggedIn check passed above).
    // Blocking these routes causes incoming order notifications to be silently lost.
    if (s.matchedLocation == '/full-screen-notification' ||
        s.matchedLocation == '/trip-start-reminder' ||
        s.matchedLocation == '/active-order') {
      if (kDebugMode) {
        debugPrint(
            '[ROUTER] ✓ Allowing notification route during PIN loading: ${s.matchedLocation}');
      }
      return null;
    }
    if (s.matchedLocation != '/pin-gate') {
      if (kDebugMode) {
        debugPrint(
            '[ROUTER] → Redirect to /pin-gate (pinStatus=${st.pinStatus})');
      }
      return '/pin-gate';
    }
    // Already on gate, stay here until status resolves
    if (kDebugMode) {
      debugPrint(
          '[ROUTER] ✓ Already on /pin-gate (waiting for pinStatus=${st.pinStatus})');
    }
    return null;
  }

  // 4. AUTHENTICATED AND NO PIN
  if (st.pinStatus == PinStatus.noPin) {
    // Allow notification routes to bypass PIN creation
    if (s.matchedLocation == '/full-screen-notification' ||
        s.matchedLocation == '/trip-start-reminder' ||
        s.matchedLocation == '/active-order') {
      if (kDebugMode) {
        debugPrint(
            '[ROUTER] ✓ Allowing notification route during noPin: ${s.matchedLocation}');
      }
      return null;
    }
    if (s.matchedLocation != '/create-pin') {
      if (kDebugMode) {
        debugPrint('[ROUTER] → Redirect to /create-pin (user has no PIN)');
      }
      return '/create-pin';
    }
    if (kDebugMode) {
      debugPrint('[ROUTER] ✓ Already on /create-pin');
    }
    return null;
  }

  // 5. BLOCKED CHECK: Driver is blocked by admin
  if (profile != null && profile.isBlocked) {
    if (s.matchedLocation != '/blocked') {
      if (kDebugMode) {
        debugPrint('[ROUTER] → Redirect to /blocked (driver is blocked)');
      }
      return '/blocked';
    }
    return null;
  }

  // 6. FULLY AUTHENTICATED: User has account + PIN (PinStatus.hasPin)
  if (st.pinStatus == PinStatus.hasPin) {
    // Redirect away from auth screens to home
    if (s.matchedLocation == '/login' ||
        s.matchedLocation == '/otp' ||
        s.matchedLocation == '/create-pin' ||
        s.matchedLocation == '/pin-gate') {
      if (kDebugMode) {
        debugPrint(
            '[ROUTER] → Redirect to / (authenticated with PIN, leaving ${s.matchedLocation})');
      }
      return '/';
    }
    if (kDebugMode) {
      debugPrint(
          '[ROUTER] ✓ Authenticated - allowing access to ${s.matchedLocation}');
    }
    return null;
  }

  // Fallback: unexpected state
  if (kDebugMode) {
    debugPrint(
        '[ROUTER] ⚠️ Unexpected state - no redirect | pinStatus=${st.pinStatus}');
  }
  return null;
}

/// Debounced ChangeNotifier used as GoRouter refreshListenable.
/// Driven by ref.listen on authProvider and driverProfileStreamProvider
/// so the router is never recreated — only redirect() is re-evaluated.
class _RouterRefreshNotifier extends ChangeNotifier {
  Timer? _debounceTimer;

  void notify() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (kDebugMode)
        debugPrint('[Router] State changed → re-evaluating redirect');
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
