import 'dart:async';

import 'package:auth_shared/auth_shared.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_screen.dart';
import '../../features/auth/auth_gate.dart';
import '../../features/auth/bug_report_screen.dart';
import '../../features/auth/create_pin_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/phone_pin_login_screen.dart';
import '../../features/auth/providers/auth_service_provider.dart';
import '../../features/auth/screens/pin_gate_screen.dart';
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
import '../logging/auth_logger.dart';
import 'navigator.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // CRITICAL FIX: Create refresh stream FIRST to store current state
  final refreshStream = _GoRouterRefreshStream(ref.read(authProvider.notifier).stream);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) => _redirect(state, refreshStream.currentState),
    refreshListenable: refreshStream,
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
        path: '/bug-report',
        name: 'bugReport',
        builder: (context, state) => const BugReportScreen(),
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

  // KEY FIX: Only redirect to /otp AFTER the code has actually been sent (codeSent).
  // During OtpStage.sending, Firebase is still running RecaptchaActivity.
  // Redirecting to /otp too early causes RecaptchaActivity to open ON TOP of the OTP screen.
  final isSending = st.otpStage == OtpStage.sending;
  final canOtp = ((st.otpFlowActive || st.otpStage == OtpStage.codeSent) && !isSending);
  final isLoading = st.isLoading;
  final userId = st.user?.uid;

  // Set route context for Crashlytics
  CrashlyticsObserver.setRoute(s.matchedLocation, s.name ?? 'unknown');

  debugPrint('[Router] NAVIGATION_CHECK | '
      'location=${s.matchedLocation} | '
      'user=$userId | '
      'pinStatus=$pinStatus | '
      'canOtp=$canOtp | '
      'isSending=$isSending | '
      'otpStage=${st.otpStage} | '
      'isLoading=$isLoading');

  // 0. CAPTCHA IN PROGRESS: Stay on /login while Firebase is sending OTP
  // This prevents RecaptchaActivity from being covered by premature OTP redirect.
  // CRITICAL FIX: Force redirect to /login during reCAPTCHA to prevent navigation conflicts
  if (isSending) {
    debugPrint('[Router] ⏳ OTP sending (CAPTCHA in progress) – staying on /login');
    if (s.matchedLocation != '/login') {
      debugPrint('[Router] → Redirecting to /login (CAPTCHA in progress)');
      return '/login';
    }
    return null;
  }

  // 1. ABSOLUTE PRIORITY - OTP FLOW: User is in OTP verification process (codeSent)
  // OTP always takes precedence over ALL other flows (including public/loading)
  if (canOtp) {
    if (s.matchedLocation != '/otp') {
      debugPrint('[Router] → Redirecting to /otp (OTP flow active)');
      AuthLogger.logRouterRedirect(s.matchedLocation, '/otp', 'OTP flow active', userId);
      return '/otp';
    }
    debugPrint('[Router] ✓ Already on /otp');
    return null;
  }

  // 2. ALLOW: Public tracking routes (no auth required)
  if (s.matchedLocation.startsWith('/track/')) {
    debugPrint('[Router] ✓ Public route - no redirect');
    return null;
  }

  // 3. WAIT: Still loading initial auth state (prevent premature redirects)
  if (isLoading && s.matchedLocation != '/login' && s.matchedLocation != '/otp') {
    debugPrint('[Router] ⏳ Auth loading - staying on current route');
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
    if (s.matchedLocation == '/login' ||
        s.matchedLocation == '/otp' ||
        s.matchedLocation == '/create-pin' ||
        s.matchedLocation == '/pin-gate') {
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
    // CRITICAL FIX: Do NOT call notifyListeners() immediately in constructor
    // This was causing go_router to rebuild before initialization completed,
    // leading to "registry.containsKey(page)" assertion failures.
    // go_router will call redirect() on initial build anyway.

    // Add debouncing to prevent rapid redirect conflicts
    // CRITICAL FIX: Skip debounce for critical OTP state changes to ensure immediate navigation
    _subscription = stream.asBroadcastStream().transform(StreamTransformer.fromHandlers(
      handleData: (AuthState data, EventSink<AuthState> sink) {
        // CRITICAL FIX: Store current state immediately (before debounce)
        // This ensures redirect() always reads the latest state
        _currentState = data;

        // Cancel any pending timer
        _debounceTimer?.cancel();

        // CRITICAL: Skip debounce for OTP critical states (codeSent, failed)
        // These need immediate navigation to prevent "about:blank" or stuck screens
        final isCriticalOtpState = data.otpStage == OtpStage.codeSent ||
                                   data.otpStage == OtpStage.failed;

        if (isCriticalOtpState) {
          // Emit immediately for critical OTP states
          sink.add(data);
        } else {
          // Set a new timer to emit after debounce period for other states
          _debounceTimer = Timer(const Duration(milliseconds: 600), () {
            sink.add(data);
          });
        }
      },
    )).listen((authState) {
      debugPrint('[Router] Auth state changed, triggering redirect check | '
          'user=${authState.user?.uid ?? 'null'} | '
          'pinStatus=${authState.pinStatus} | '
          'otpStage=${authState.otpStage}');
      notifyListeners();
    });
  }

  // CRITICAL FIX: Store current state for immediate access by redirect()
  AuthState _currentState = const AuthState();
  AuthState get currentState => _currentState;

  late final StreamSubscription<AuthState> _subscription;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
