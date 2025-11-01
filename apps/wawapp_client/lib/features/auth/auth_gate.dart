import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'phone_pin_login_screen.dart';

class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const PhonePinLoginScreen();
        return child;
      },
    );
  }
}
