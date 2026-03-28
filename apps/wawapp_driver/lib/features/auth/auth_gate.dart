import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/testlab_flags.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';
import '../../testlab/testlab_home.dart';
import 'providers/auth_service_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _lastInitializedUserId;

  void _initializeServicesOnce(String userId, BuildContext context) {
    if (_lastInitializedUserId == userId) {
      return; // Already initialized for this user
    }

    // We no longer have direct access to firestore data here
    // Properties will be set when profile is loaded in specific screens if needed
    AnalyticsService.instance.setUserProperties(
      userId: userId,
      // totalTrips, rating, etc. removed as we don't fetch doc here anymore
      // logic for these specific properties should move to where profile is actually fetched
    );
    AnalyticsService.instance.logAuthCompleted(method: 'phone_pin');
    FCMService.instance.initialize(context);

    _lastInitializedUserId = userId;
  }

  @override
  Widget build(BuildContext context) {
    // Check Test Lab mode first - bypass all logic
    if (TestLabFlags.safeEnabled) {
      debugPrint('[AuthGate] REDIRECT_REASON=TEST_LAB_MODE → TestLabHome');
      return const TestLabHome();
    }

    final authState = ref.watch(authProvider);

    // One-time service initialization when user is present
    final user = authState.user;
    if (user != null) {
      // Defer to next frame to ensure safe context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeServicesOnce(user.uid, context);
        }
      });
    }

    // Passive wrapper: checking auth, pin, etc. is now done by AppRouter
    return widget.child;
  }
}
