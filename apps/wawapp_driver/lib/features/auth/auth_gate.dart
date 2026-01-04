import 'package:auth_shared/auth_shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/testlab_flags.dart';
import '../../core/config/testlab_mock_data.dart';
import '../../core/theme/colors.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';
import '../../testlab/testlab_home.dart';
import '../home/driver_home_screen.dart';
import 'create_pin_screen.dart';
import 'otp_screen.dart';
import 'phone_pin_login_screen.dart';
import 'providers/auth_service_provider.dart';

// StreamProvider for driver profile
final driverProfileProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  // Return mock profile for Test Lab mode
  if (TestLabFlags.safeEnabled) {
    return Stream.value(TestLabMockData.mockDriverDoc);
  }

  final authState = ref.watch(authProvider);

  // CRITICAL: Use the new isStreamsSafeToRun flag to prevent permission errors
  // This flag is set to false BEFORE any auth transitions (OTP, PIN reset, logout)
  if (!authState.isStreamsSafeToRun || authState.user == null) {
    return Stream.value(null);
  }

  // Defensive: Capture UID in local variable to prevent race condition
  final uid = authState.user!.uid;

  return FirebaseFirestore.instance
      .collection('drivers')
      .doc(uid)
      .snapshots()
      .handleError((error) {
    // Gracefully handle permission errors that may occur during race conditions
    debugPrint(
        '[DriverProfileProvider] Stream error (likely during transition): $error');
    return null;
  });
});

class AuthGate extends ConsumerStatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _lastInitializedUserId;

  void _initializeServicesOnce(
      String userId, BuildContext context, Map<String, dynamic>? data) {
    if (_lastInitializedUserId == userId) {
      return; // Already initialized for this user
    }

    AnalyticsService.instance.setUserProperties(
      userId: userId,
      totalTrips: data?['totalTrips'] as int?,
      averageRating: (data?['rating'] as num?)?.toDouble(),
      isVerified: data?['isVerified'] as bool?,
    );
    AnalyticsService.instance.logAuthCompleted(method: 'phone_pin');
    FCMService.instance.initialize(context);

    _lastInitializedUserId = userId;
  }

  @override
  Widget build(BuildContext context) {
    // Check Test Lab mode first - bypass all auth logic
    if (TestLabFlags.safeEnabled) {
      debugPrint('[AuthGate] REDIRECT_REASON=TEST_LAB_MODE → TestLabHome');
      return const TestLabHome();
    }

    final authState = ref.watch(authProvider);

    debugPrint(
        '[AuthGate] NAVIGATION_DECISION | user: ${authState.user?.uid}, isLoading: ${authState.isLoading}, isPinCheckLoading: ${authState.isPinCheckLoading}, otpStage: ${authState.otpStage}, pinStatus: ${authState.pinStatus}');

    // Show loading while checking auth state OR checking PIN
    if (authState.isLoading || authState.isPinCheckLoading) {
      debugPrint(
          '[AuthGate] REDIRECT_REASON=AUTH_LOADING → CircularProgressIndicator');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check if we're in OTP flow (regardless of user state)
    // This handles both new registration and PIN reset flows
    if (authState.otpStage == OtpStage.codeSent) {
      debugPrint('[AuthGate] REDIRECT_REASON=OTP_CODE_SENT → OtpScreen');
      return const OtpScreen();
    }

    // No user - show login screen
    if (authState.user == null) {
      debugPrint('[AuthGate] REDIRECT_REASON=SIGNED_OUT → PhonePinLoginScreen');
      return const PhonePinLoginScreen();
    }

    // User exists - check driver profile for PIN
    final driverProfileAsync = ref.watch(driverProfileProvider);

    return driverProfileAsync.when(
      loading: () {
        debugPrint(
            '[AuthGate] REDIRECT_REASON=PROFILE_LOADING → CircularProgressIndicator');
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stackTrace) {
        debugPrint('[AuthGate] PROFILE_ERROR: $error');

        // If permission-denied, show create PIN screen instead of logging out
        if (error.toString().contains('permission-denied')) {
          debugPrint(
              '[AuthGate] REDIRECT_REASON=PERMISSION_DENIED → CreatePinScreen');
          return const CreatePinScreen();
        }

        // For other errors, show error screen
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error,
                    size: 64, color: DriverAppColors.errorLight),
                const SizedBox(height: 16),
                Text(
                  'Unable to access driver profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: $error',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
      data: (doc) {
        debugPrint('[AuthGate] driver doc exists: ${doc?.exists}');

        // CRITICAL: Check PIN reset flow FIRST before checking Firestore
        // During PIN reset, user must go to CreatePinScreen even if they have existing PIN
        if (authState.isPinResetFlow) {
          debugPrint(
              '[AuthGate] REDIRECT_REASON=PIN_RESET_FLOW → CreatePinScreen (isPinResetFlow=true)');
          return const CreatePinScreen();
        }

        // If driver document doesn't exist, show CreatePinScreen
        // The document will be created when user sets PIN (via PhonePinAuth.setPin)
        if (doc == null || !doc.exists) {
          debugPrint(
              '[AuthGate] REDIRECT_REASON=NO_DRIVER_DOC → CreatePinScreen');
          return const CreatePinScreen();
        }

        final data = doc.data();
        final hasPin =
            data?['pinHash'] != null && (data!['pinHash'] as String).isNotEmpty;

        debugPrint('[AuthGate] driver hasPin: $hasPin');

        if (!hasPin) {
          debugPrint(
              '[AuthGate] REDIRECT_REASON=NO_PIN_HASH → CreatePinScreen');
          return const CreatePinScreen();
        }

        // Set user properties after successful auth with PIN
        // Initialize services only once per user to prevent infinite rebuild loop
        final user = authState.user;
        if (user != null) {
          _initializeServicesOnce(user.uid, context, data);

          // ANALYTICS VALIDATION:
          // To verify: adb shell setprop debug.firebase.analytics.app com.wawapp.driver
          // Check Firebase Console → DebugView for:
          //   - Event: auth_completed (method: phone_pin)
          //   - User property: user_type = driver
          //   - User properties: total_trips, average_rating, is_verified
        }

        debugPrint(
            '[AuthGate] REDIRECT_REASON=AUTHENTICATED_WITH_PIN → DriverHomeScreen');
        return const DriverHomeScreen();
      },
    );
  }
}
