import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    debugPrint('[AuthGate] GUARD_CHECK | '
        'user=${authState.user?.uid ?? 'null'} | '
        'hasPin=${authState.hasPin} | '
        'isLoading=${authState.isLoading} | '
        'isPinCheckLoading=${authState.isPinCheckLoading}');

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

    // If still checking for PIN existence, show loading
    if (authState.isPinCheckLoading) {
      debugPrint('[AuthGate] ⏳ PIN check loading - showing spinner');
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Otherwise, show the protected content
    // Router will handle redirects if user is not authenticated
    debugPrint('[AuthGate] ✓ Showing protected content');
    return child;
  }
}
