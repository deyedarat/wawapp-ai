import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/auth_logger.dart';
import 'providers/auth_service_provider.dart';

/// AuthGate is now a PASSIVE guard that only:
/// 1. Shows loading screen during auth initialization
/// 2. Wraps protected content
///
/// Navigation logic is handled by GoRouter's redirect function.
/// This prevents conflicts between AuthGate widget swapping and Router URL changes.
class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    AuthLogger.logAuthGate(
      'Guard check: pinStatus=${authState.pinStatus}, isLoading=${authState.isLoading}',
      authState.user?.uid,
    );

    // ONLY show loading screen during initial auth check
    // (when we don't know if user exists yet)
    if (authState.user == null && authState.isLoading) {
      debugPrint('[AuthGate] ⏳ Initial auth loading - showing spinner');
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Otherwise, show the protected content
    // Router will handle redirects based on PinStatus
    debugPrint('[AuthGate] ✓ Showing protected content');
    return child;
  }
}
