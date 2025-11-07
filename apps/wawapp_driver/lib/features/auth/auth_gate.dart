import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_service_provider.dart';
import 'phone_pin_login_screen.dart';

class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Show loading indicator while initializing
    if (authState.user == null && authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If no user, show login screen
    if (authState.user == null) {
      return const PhonePinLoginScreen();
    }

    // User is authenticated, show protected content
    return child;
  }
}
