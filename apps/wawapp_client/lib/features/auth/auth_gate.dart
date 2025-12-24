import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_service_provider.dart';
import 'phone_pin_login_screen.dart';
import 'create_pin_screen.dart';

class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // DEBUG: Log AuthGate state
    debugPrint('[AuthGate] user=${authState.user?.uid ?? 'null'} hasPin=${authState.hasPin} isLoading=${authState.isLoading}');

    // Show loading indicator while initializing
    if (authState.user == null && authState.isLoading) {
      debugPrint('[AuthGate] -> Loading screen');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If no user, show login screen
    if (authState.user == null) {
      debugPrint('[AuthGate] -> PhonePinLoginScreen (no user)');
      return const PhonePinLoginScreen();
    }

    // If user exists but no PIN, enforce PIN creation
    if (authState.user != null && !authState.hasPin) {
      debugPrint('[AuthGate] -> CreatePinScreen (user exists, no PIN)');
      return const CreatePinScreen();
    }

    // User is authenticated, show protected content
    debugPrint('[AuthGate] -> Protected content (user authenticated with PIN)');
    return child;
  }
}
