import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../features/home/home_screen.dart';
import '../../features/quote/quote_screen.dart';
import '../../features/track/track_screen.dart';
import '../../features/track/driver_found_screen.dart';
import '../../features/track/public_track_screen.dart';
import '../../features/track/trip_completed_screen.dart';

import '../../features/about/about_screen.dart';
import '../../features/auth/phone_pin_login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/create_pin_screen.dart';
import '../../features/auth/providers/auth_service_provider.dart';
import '../../features/profile/client_profile_screen.dart';
import '../../features/profile/client_profile_edit_screen.dart';
import '../../features/profile/saved_locations_screen.dart';
import '../../features/profile/add_saved_location_screen.dart';
import 'package:auth_shared/auth_shared.dart';
import 'package:core_shared/core_shared.dart';
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
        builder: (context, state) => const HomeScreen(),
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
  final canOtp = (st.otpFlowActive == true) || (st.verificationId != null);

  debugPrint(
      '[Router] loc=${s.matchedLocation} loggedIn=$loggedIn canOtp=$canOtp otpStage=${st.otpStage}');

  // Allow public tracking without authentication
  if (s.matchedLocation.startsWith('/track/')) {
    debugPrint('[Router] Allowing public tracking access');
    return null;
  }

  // Allow OTP route when canOtp is true
  if (!loggedIn && canOtp && s.matchedLocation != '/otp') {
    debugPrint('[Router] Redirecting to /otp (canOtp=true)');
    return '/otp';
  }

  // Not logged in and not in OTP flow
  if (!loggedIn && !canOtp && s.matchedLocation != '/login') {
    debugPrint('[Router] Redirecting to /login (not authenticated)');
    return '/login';
  }

  // Logged in but on login page
  if (loggedIn && s.matchedLocation == '/login') {
    debugPrint('[Router] Redirecting to / (already authenticated)');
    return '/';
  }

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
