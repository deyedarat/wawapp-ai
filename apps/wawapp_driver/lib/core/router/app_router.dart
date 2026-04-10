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
import 'navigator.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final driverProfile = ref.watch(driverProfileStreamProvider).valueOrNull;

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) => _redirect(state, authState, driverProfile),
    refreshListenable: _GoRouterRefreshStream(ref.read(authProvider.notifier).stream),
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
            return FullScreenNotificationScreen(data: extra);
          }

          // 2. Try query parameters (deep links / notification tap)
          final params = state.uri.queryParameters;
          final data = FullScreenNotificationData.tryParse(params);
          if (data != null) {
            return FullScreenNotificationScreen(data: data);
          }

          // 3. Fallback — missing or invalid data
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
            return TripStartReminderScreen(data: extra);
          }

          // 2. Try query parameters (deep links / notification tap)
          final params = state.uri.queryParameters;
          final data = TripStartReminderData.tryParse(params);
          if (data != null) {
            return TripStartReminderScreen(data: data);
          }

          // 3. Fallback — missing or invalid data, redirect to active order
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
});

String? _redirect(GoRouterState s, AuthState st, DriverProfile? profile) {
  final loggedIn = st.user != null;
  final canOtp = st.otpFlowActive || st.otpStage == OtpStage.sending || st.otpStage == OtpStage.codeSent;

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
        debugPrint('[ROUTER] → Redirect to /otp (OTP flow active, otpStage=${st.otpStage})');
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
  if (st.pinStatus == PinStatus.unknown || st.pinStatus == PinStatus.loading || st.pinStatus == PinStatus.error) {
    if (s.matchedLocation != '/pin-gate') {
      if (kDebugMode) {
        debugPrint('[ROUTER] → Redirect to /pin-gate (pinStatus=${st.pinStatus})');
      }
      return '/pin-gate';
    }
    // Already on gate, stay here until status resolves
    if (kDebugMode) {
      debugPrint('[ROUTER] ✓ Already on /pin-gate (waiting for pinStatus=${st.pinStatus})');
    }
    return null;
  }

  // 4. AUTHENTICATED AND NO PIN
  if (st.pinStatus == PinStatus.noPin) {
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
        debugPrint('[ROUTER] → Redirect to / (authenticated with PIN, leaving ${s.matchedLocation})');
      }
      return '/';
    }
    if (kDebugMode) {
      debugPrint('[ROUTER] ✓ Authenticated - allowing access to ${s.matchedLocation}');
    }
    return null;
  }

  // Fallback: unexpected state
  if (kDebugMode) {
    debugPrint('[ROUTER] ⚠️ Unexpected state - no redirect | pinStatus=${st.pinStatus}');
  }
  return null;
}

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<AuthState> stream) {
    // CRITICAL FIX: Do NOT call notifyListeners() immediately in constructor
    // This was causing go_router to rebuild before initialization completed,
    // leading to "registry.containsKey(page)" assertion failures.
    // go_router will call redirect() on initial build anyway.

    // Add debouncing to prevent rapid redirect conflicts
    _subscription = stream.asBroadcastStream().transform(StreamTransformer.fromHandlers(
      handleData: (AuthState data, EventSink<AuthState> sink) {
        // Cancel any pending timer
        _debounceTimer?.cancel();

        // Set a new timer to emit after debounce period
        _debounceTimer = Timer(const Duration(milliseconds: 100), () {
          sink.add(data);
        });
      },
    )).listen((authState) {
      if (kDebugMode) {
        debugPrint('[Router] Auth state changed, triggering redirect check | '
            'user=${authState.user?.uid ?? 'null'} | '
            'pinStatus=${authState.pinStatus} | '
            'otpStage=${authState.otpStage}');
      }
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
