/**
 * Admin Authentication Providers
 * Riverpod providers for admin authentication state
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_auth_service.dart';

/// Admin Auth Service Provider
final adminAuthServiceProvider = Provider<AdminAuthService>((ref) {
  return AdminAuthService();
});

/// Auth State Stream Provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(adminAuthServiceProvider);
  return authService.authStateChanges;
});

/// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user,
    orElse: () => null,
  );
});

/// Is Admin Check Provider
final isAdminProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(adminAuthServiceProvider);
  return await authService.isAdmin();
});

/// Admin Profile Provider
final adminProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authService = ref.watch(adminAuthServiceProvider);
  return await authService.getAdminProfile();
});
