import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/auth_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../services/phone_auth_service.dart';
import '../utils/lockout_manager.dart';
import 'auth_notifier.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final phoneAuthServiceProvider = Provider<PhoneAuthService>((ref) {
  return PhoneAuthService();
});

final lockoutManagerProvider = Provider<LockoutManager>((ref) {
  return LockoutManager();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(phoneAuthServiceProvider),
    ref.watch(lockoutManagerProvider),
  );
});
