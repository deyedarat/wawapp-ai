import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auth_shared/auth_shared.dart';
import 'create_pin_screen.dart';
import 'otp_screen.dart';
import 'phone_pin_login_screen.dart';
import 'providers/auth_service_provider.dart';
import '../home/driver_home_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';
import '../../core/theme/colors.dart';

// StreamProvider for driver profile
final driverProfileProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;

  if (user == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('drivers')
      .doc(user.uid)
      .snapshots();
});

class AuthGate extends ConsumerStatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _lastInitializedUserId;

  void _initializeServicesOnce(String userId, BuildContext context, Map<String, dynamic>? data) {
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
    final authState = ref.watch(authProvider);

    debugPrint(
        '[AuthGate] user: ${authState.user?.uid}, isLoading: ${authState.isLoading}, otpStage: ${authState.otpStage}');

    // Show loading while checking auth state
    if (authState.isLoading) {
      debugPrint('[AuthGate] showing loading (auth state loading)');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // No user - check if we're in OTP flow
    if (authState.user == null) {
      // If OTP was sent successfully, show OTP screen
      if (authState.otpStage == OtpStage.codeSent) {
        debugPrint('[AuthGate] showing OtpScreen (OTP sent)');
        return const OtpScreen();
      }

      debugPrint('[AuthGate] showing PhonePinLoginScreen (no user)');
      return const PhonePinLoginScreen();
    }

    // User exists - check driver profile for PIN
    final driverProfileAsync = ref.watch(driverProfileProvider);

    return driverProfileAsync.when(
      loading: () {
        debugPrint('[AuthGate] showing loading (driver profile loading)');
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stackTrace) {
        debugPrint('[AuthGate] error loading driver profile: $error');
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: DriverAppColors.errorLight),
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

        final data = doc?.data();
        final hasPin =
            data?['pinHash'] != null && (data!['pinHash'] as String).isNotEmpty;

        debugPrint('[AuthGate] driver hasPin: $hasPin');

        if (!hasPin) {
          debugPrint('[AuthGate] showing CreatePinScreen (no PIN yet)');
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

        debugPrint('[AuthGate] showing DriverHomeScreen (user + PIN)');
        return const DriverHomeScreen();
      },
    );
  }
}
