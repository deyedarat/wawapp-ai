import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auth_shared/auth_shared.dart';

final phonePinAuthServiceProvider = Provider<PhonePinAuth>((ref) {
  return PhonePinAuth(userCollection: 'users');
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(phonePinAuthServiceProvider);
  final firebaseAuth = FirebaseAuth.instance;
  return AuthNotifier(authService, firebaseAuth);
});
