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
import '../../features/home/home_screen.dart';
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
import '../observability/crashlytics_observer.dart';
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
  final hasPin = st.hasPin;
  final canOtp = st.otpFlowActive ||
      st.otpStage == OtpStage.sending ||
      st.otpStage == OtpStage.codeSent;
  final isLoading = st.isLoading || st.isPinCheckLoading;

  // Set route context for Crashlytics
  CrashlyticsObserver.setRoute(s.matchedLocation, s.name ?? 'unknown');

  debugPrint('[Router] NAVIGATION_CHECK | '
      'location=${s.matchedLocation} | '
      'user=${st.user?.uid ?? 'null'} | '
      'hasPin=$hasPin | '
      'canOtp=$canOtp | '
      'otpStage=${st.otpStage} | '
      'isLoading=$isLoading');

  // 1. ALLOW: Public tracking routes (no auth required)
  if (s.matchedLocation.startsWith('/track/')) {
    debugPrint('[Router] ✓ Public route - no redirect');
    return null;
  }

  // 2. WAIT: Still loading auth state (prevent premature redirects)
  if (isLoading &&
      s.matchedLocation != '/login' &&
      s.matchedLocation != '/otp') {
    debugPrint('[Router] ⏳ Auth loading - staying on current route');
    return null;
  }

  // 3. OTP FLOW: User is in OTP verification process
  if (canOtp) {
    if (s.matchedLocation != '/otp') {
      debugPrint('[Router] → Redirecting to /otp (OTP flow active)');
      return '/otp';
    }
    debugPrint('[Router] ✓ Already on /otp');
    return null;
  }

  // 4. NOT AUTHENTICATED: No user
  if (!loggedIn) {
    if (s.matchedLocation != '/login') {
      debugPrint('[Router] → Redirecting to /login (not authenticated)');
      return '/login';
    }
    debugPrint('[Router] ✓ Already on /login');
    return null;
  }

  // 5. AUTHENTICATED BUT NO PIN: User needs to create PIN
  if (loggedIn && !hasPin) {
    if (s.matchedLocation != '/create-pin') {
      debugPrint('[Router] → Redirecting to /create-pin (user has no PIN)');
      return '/create-pin';
    }
    debugPrint('[Router] ✓ Already on /create-pin');
    return null;
  }

  // 6. FULLY AUTHENTICATED: User has account + PIN
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
