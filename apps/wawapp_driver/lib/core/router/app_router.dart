import 'dart:async';

import 'package:auth_shared/auth_shared.dart';
import 'package:core_shared/core_shared.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/active/active_order_screen.dart';
import '../../features/auth/auth_gate.dart';
import '../../features/auth/create_pin_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/phone_pin_login_screen.dart';
import '../../features/auth/providers/auth_service_provider.dart';
import '../../features/earnings/driver_earnings_screen.dart';
import '../../features/history/driver_history_screen.dart';
import '../../features/history/order_details_screen.dart';
import '../../features/home/driver_home_screen.dart';
import '../../features/nearby/nearby_screen.dart';
import '../../features/profile/driver_profile_edit_screen.dart';
import '../../features/profile/driver_profile_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import 'navigator.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) => _redirect(state, authState),
    refreshListenable:
        _GoRouterRefreshStream(ref.read(authProvider.notifier).stream),
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
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

String? _redirect(GoRouterState s, AuthState st) {
  final loggedIn = st.user != null;
  final hasPin = st.hasPin;
  final canOtp = st.otpFlowActive ||
      st.otpStage == OtpStage.sending ||
      st.otpStage == OtpStage.codeSent;
  final isLoading = st.isLoading || st.isPinCheckLoading;

  debugPrint('[Router] NAVIGATION_CHECK | '
      'location=${s.matchedLocation} | '
      'user=${st.user?.uid ?? 'null'} | '
      'hasPin=$hasPin | '
      'canOtp=$canOtp | '
      'otpStage=${st.otpStage} | '
      'isLoading=$isLoading');

  // 1. WAIT: Still loading auth state (prevent premature redirects)
  if (isLoading &&
      s.matchedLocation != '/login' &&
      s.matchedLocation != '/otp') {
    debugPrint('[Router] ⏳ Auth loading - staying on current route');
    return null;
  }

  // 2. OTP FLOW: User is in OTP verification process
  if (canOtp) {
    if (s.matchedLocation != '/otp') {
      debugPrint('[Router] → Redirecting to /otp (OTP flow active)');
      return '/otp';
    }
    debugPrint('[Router] ✓ Already on /otp');
    return null;
  }

  // 3. NOT AUTHENTICATED: No user
  if (!loggedIn) {
    if (s.matchedLocation != '/login') {
      debugPrint('[Router] → Redirecting to /login (not authenticated)');
      return '/login';
    }
    debugPrint('[Router] ✓ Already on /login');
    return null;
  }

  // 4. AUTHENTICATED BUT NO PIN: User needs to create PIN
  if (loggedIn && !hasPin) {
    if (s.matchedLocation != '/create-pin') {
      debugPrint('[Router] → Redirecting to /create-pin (user has no PIN)');
      return '/create-pin';
    }
    debugPrint('[Router] ✓ Already on /create-pin');
    return null;
  }

  // 5. FULLY AUTHENTICATED: User has account + PIN
  if (loggedIn && hasPin) {
    // Redirect away from auth screens to home
    if (s.matchedLocation == '/login' ||
        s.matchedLocation == '/otp' ||
        s.matchedLocation == '/create-pin') {
      debugPrint(
          '[Router] → Redirecting to / (authenticated with PIN, leaving auth screen)');
      return '/';
    }
    debugPrint(
        '[Router] ✓ Authenticated - allowing access to ${s.matchedLocation}');
    return null;
  }

  debugPrint('[Router] ⚠️ Unexpected state - no redirect');
  return null;
}

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
