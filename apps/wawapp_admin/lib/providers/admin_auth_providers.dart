/**
 * Admin Authentication Providers
 * Riverpod providers for admin authentication state
 * 
 * Automatically selects correct auth service based on environment:
 * - DEV: Uses AdminAuthServiceDev (bypasses isAdmin check)
 * - STAGING/PROD: Uses AdminAuthService (enforces isAdmin check)
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_auth_service_dev.dart';

/// App Configuration Provider
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfigFactory.current;
});

/// Admin Auth Service Provider
/// Automatically selects dev or production service based on environment
final adminAuthServiceProvider = Provider<dynamic>((ref) {
  final config = ref.watch(appConfigProvider);
  
  if (config.useStrictAuth) {
    // PRODUCTION/STAGING: Use strict auth with isAdmin claim check
    return AdminAuthService();
  } else {
    // DEVELOPMENT: Use bypass auth (no claim check)
    // ⚠️ WARNING: This allows any authenticated user to access admin panel
    return AdminAuthServiceDev();
  }
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
