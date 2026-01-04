import 'dart:async';

import 'package:auth_shared/auth_shared.dart';
import 'package:core_shared/core_shared.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_screen.dart';
import '../../features/auth/auth_gate.dart';
import '../../features/auth/create_pin_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/phone_pin_login_screen.dart';
import '../../features/auth/providers/auth_service_provider.dart';
import '../../features/auth/screens/pin_gate_screen.dart';
import '../logging/auth_logger.dart';
import '../../features/home/home_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/add_saved_location_screen.dart';
import '../../features/profile/change_pin_screen.dart';
import '../../features/profile/client_profile_edit_screen.dart';
import '../../features/profile/client_profile_screen.dart';
import '../../features/profile/saved_locations_screen.dart';
import '../../features/quote/quote_screen.dart';
import '../../features/shipment_type/shipment_type_screen.dart';
import '../../features/track/driver_found_screen.dart';
import '../../features/track/public_track_screen.dart';
import '../../features/track/track_screen.dart';
import '../../features/track/trip_completed_screen.dart';
import 'navigator.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) => _redirect(state, authState),
    refreshListenable: _GoRouterRefreshStream(ref.read(authProvider.notifier).stream),
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    routes: [
      GoRoute(
        path: '/shipment-type',
        name: 'shipment-type',
        builder: (context, state) => const ShipmentTypeScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const AuthGate(child: HomeScreen()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const PhonePinLoginScreen(),
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
        path: '/quote',
        name: 'quote',
        builder: (context, state) => const QuoteScreen(),
      ),
      GoRoute(
        path: '/track',
        name: 'track',
        builder: (context, state) => TrackScreen(order: state.extra as Order?),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/driver-found/:orderId',
        name: 'driverFound',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return DriverFoundScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/track/:orderId',
        name: 'trackById',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return PublicTrackScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/trip-completed/:orderId',
        name: 'tripCompleted',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return TripCompletedScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ClientProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'profileEdit',
        builder: (context, state) => const ClientProfileEditScreen(),
      ),
      GoRoute(
        path: '/profile/change-pin',
        name: 'changePin',
        builder: (context, state) => const ChangePinScreen(),
      ),
      GoRoute(
        path: '/profile/locations',
        name: 'savedLocations',
        builder: (context, state) => const SavedLocationsScreen(),
      ),
      GoRoute(
        path: '/profile/locations/add',
        name: 'addSavedLocation',
        builder: (context, state) => const AddSavedLocationScreen(),
      ),
      GoRoute(
        path: '/profile/locations/edit/:locationId',
        name: 'editSavedLocation',
        builder: (context, state) {
          final locationId = state.pathParameters['locationId']!;
          return AddSavedLocationScreen(locationId: locationId);
        },
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
  final pinStatus = st.pinStatus;
  final canOtp = st.otpFlowActive || st.otpStage == OtpStage.sending || st.otpStage == OtpStage.codeSent;
  final isLoading = st.isLoading;
  final userId = st.user?.uid;

  // Set route context for Crashlytics
  CrashlyticsObserver.setRoute(s.matchedLocation, s.name ?? 'unknown');

  debugPrint('[Router] NAVIGATION_CHECK | '
      'location=${s.matchedLocation} | '
      'user=$userId | '
      'pinStatus=$pinStatus | '
      'canOtp=$canOtp | '
      'otpStage=${st.otpStage} | '
      'isLoading=$isLoading');

  // 1. ALLOW: Public tracking routes (no auth required)
  if (s.matchedLocation.startsWith('/track/')) {
    debugPrint('[Router] ✓ Public route - no redirect');
    return null;
  }

  // 2. WAIT: Still loading initial auth state (prevent premature redirects)
  if (isLoading && s.matchedLocation != '/login' && s.matchedLocation != '/otp') {
    debugPrint('[Router] ⏳ Auth loading - staying on current route');
    return null;
  }

  // 3. PRIORITY 1 - OTP FLOW: User is in OTP verification process
  // OTP always takes precedence over other flows
  if (canOtp) {
    if (s.matchedLocation != '/otp') {
      debugPrint('[Router] → Redirecting to /otp (OTP flow active)');
      AuthLogger.logRouterRedirect(s.matchedLocation, '/otp', 'OTP flow active', userId);
      return '/otp';
    }
    debugPrint('[Router] ✓ Already on /otp');
    return null;
  }

  // 4. PRIORITY 2 - NOT AUTHENTICATED: No user
  if (!loggedIn) {
    if (s.matchedLocation != '/login') {
      debugPrint('[Router] → Redirecting to /login (not authenticated)');
      AuthLogger.logRouterRedirect(s.matchedLocation, '/login', 'Not authenticated', null);
      return '/login';
    }
    debugPrint('[Router] ✓ Already on /login');
    return null;
  }

  // 5. PRIORITY 3 - PIN STATUS GATE: Resolve unknown/loading/error states
  // Redirect to /pin-gate UNLESS we're already there or in a known state
  if (pinStatus == PinStatus.unknown || pinStatus == PinStatus.loading || pinStatus == PinStatus.error) {
    if (s.matchedLocation != '/pin-gate') {
      debugPrint('[Router] → Redirecting to /pin-gate (pinStatus=$pinStatus)');
      AuthLogger.logRouterRedirect(s.matchedLocation, '/pin-gate', 'PinStatus=$pinStatus', userId);
      return '/pin-gate';
    }
    debugPrint('[Router] ✓ Already on /pin-gate');
    return null;
  }

  // 6. PRIORITY 4 - AUTHENTICATED BUT NO PIN: User needs to create PIN
  if (loggedIn && pinStatus == PinStatus.noPin) {
    if (s.matchedLocation != '/create-pin') {
      debugPrint('[Router] → Redirecting to /create-pin (user has no PIN)');
      AuthLogger.logRouterRedirect(s.matchedLocation, '/create-pin', 'No PIN set', userId);
      return '/create-pin';
    }
    debugPrint('[Router] ✓ Already on /create-pin');
    return null;
  }

  // 7. PRIORITY 5 - FULLY AUTHENTICATED: User has account + PIN
  if (loggedIn && pinStatus == PinStatus.hasPin) {
    // Redirect away from auth screens to home
    if (s.matchedLocation == '/login' || s.matchedLocation == '/otp' || 
        s.matchedLocation == '/create-pin' || s.matchedLocation == '/pin-gate') {
      debugPrint('[Router] → Redirecting to / (authenticated with PIN, leaving auth screen)');
      AuthLogger.logRouterRedirect(s.matchedLocation, '/', 'Authenticated with PIN', userId);
      return '/';
    }
    debugPrint('[Router] ✓ Authenticated - allowing access to ${s.matchedLocation}');
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
