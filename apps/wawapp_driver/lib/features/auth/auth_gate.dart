import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'create_pin_screen.dart';
import 'phone_pin_login_screen.dart';
import '../home/driver_home_screen.dart';

// StreamProvider for driver profile
final driverProfileProvider = StreamProvider<DocumentSnapshot?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (kDebugMode) {
        print('[AuthGate] No authenticated user -> PhonePinLoginScreen');
      }
      return const PhonePinLoginScreen();
    }

    final driverProfileAsync = ref.watch(driverProfileProvider);

    return driverProfileAsync.when(
      loading: () {
        if (kDebugMode) {
          print('[AuthGate] Loading driver profile...');
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stackTrace) {
        if (kDebugMode) {
          print('[AuthGate] Error loading driver profile: $error');
        }
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
      data: (snapshot) {
        final hasPin = snapshot?.data() != null &&
            (snapshot!.data() as Map<String, dynamic>)['pinHash'] != null;

        if (!hasPin) {
          if (kDebugMode) {
            print('[AuthGate] driver profile loaded, hasPin=false -> showing CreatePinScreen');
          }
          return const CreatePinScreen();
        }

        if (kDebugMode) {
          print('[AuthGate] driver profile updated, hasPin=true -> showing DriverHomeScreen');
        }
        return const DriverHomeScreen();
      },
    );
  }
}
