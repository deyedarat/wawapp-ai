import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'create_pin_screen.dart';
import 'phone_pin_login_screen.dart';
import '../home/driver_home_screen.dart';

class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const PhonePinLoginScreen();
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('drivers').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final hasPin = snapshot.data?.data() != null &&
            (snapshot.data!.data() as Map<String, dynamic>)['pinHash'] != null;

        if (!hasPin) {
          return const CreatePinScreen();
        }

        return const DriverHomeScreen();
      },
    );
  }
}
