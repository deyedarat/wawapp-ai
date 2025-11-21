import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'create_pin_screen.dart';
import 'phone_pin_login_screen.dart';
import 'providers/auth_service_provider.dart';
import '../home/driver_home_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';

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

class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    debugPrint(
        '[AuthGate] user: ${authState.user?.uid}, isLoading: ${authState.isLoading}');

    // Show loading while checking auth state
    if (authState.isLoading) {
      debugPrint('[AuthGate] showing loading (auth state loading)');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // No user - show login screen
    if (authState.user == null) {
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
                const Icon(Icons.error, size: 64, color: Colors.red),
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
        final user = authState.user;
        if (user != null) {
          AnalyticsService.instance.setUserProperties(
            userId: user.uid,
            totalTrips: data?['totalTrips'] as int?,
            averageRating: (data?['rating'] as num?)?.toDouble(),
            isVerified: data?['isVerified'] as bool?,
          );
          AnalyticsService.instance.logAuthCompleted(method: 'phone_pin');
          
          // Initialize FCM for push notifications
          FCMService.instance.initialize(context);
          
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
