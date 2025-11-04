import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../services/phone_auth_service.dart';
import '../../utils/lockout_manager.dart';
import '../../domain/entities/user_entity.dart';

// Repository providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final phoneAuthServiceProvider = Provider<PhoneAuthService>((ref) {
  return PhoneAuthService();
});

final lockoutManagerProvider = Provider<LockoutManager>((ref) {
  return LockoutManager();
});

// Auth state
class AuthState {
  final UserEntity? user;
  final bool isLoading;
  final String? error;
  final String? verificationId;
  final String? phoneNumber;
  final Duration? lockoutDuration;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.verificationId,
    this.phoneNumber,
    this.lockoutDuration,
  });

  AuthState copyWith({
    UserEntity? user,
    bool? isLoading,
    String? error,
    String? verificationId,
    String? phoneNumber,
    Duration? lockoutDuration,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      verificationId: verificationId,
      phoneNumber: phoneNumber,
      lockoutDuration: lockoutDuration,
    );
  }

  bool get isAuthenticated => user != null;
  bool get hasError => error != null;
  bool get isLocked => lockoutDuration != null;
}

// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final PhoneAuthService _phoneService;
  final LockoutManager _lockoutManager;

  AuthNotifier(this._authRepository, this._phoneService, this._lockoutManager)
      : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(user: user);
      }
    } catch (e) {
      // Silent fail for initial check
    }
  }

  Future<void> sendOTP(String phoneNumber) async {
    if (!PhoneAuthService.isValidPhoneNumber(phoneNumber)) {
      state = state.copyWith(error: 'Invalid phone number format');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      String? verificationId;
      String? error;

      await _phoneService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (id) => verificationId = id,
        onError: (err) => error = err,
      );

      if (error != null) {
        state = state.copyWith(isLoading: false, error: error);
      } else if (verificationId != null) {
        state = state.copyWith(
          isLoading: false,
          verificationId: verificationId,
          phoneNumber: phoneNumber,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> verifyOTP({
    required String verificationId,
    required String otp,
    required String pin,
    required String accountType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _authRepository.verifyOTPAndCreateAccount(
        verificationId: verificationId,
        otp: otp,
        pin: pin,
        accountType: accountType,
      );

      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginWithPin({
    required String phoneNumber,
    required String pin,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final lockoutDuration = await _lockoutManager.getLockoutDuration(phoneNumber);
      if (lockoutDuration != null) {
        state = state.copyWith(
          isLoading: false,
          lockoutDuration: lockoutDuration,
        );
        return;
      }

      final user = await _authRepository.loginWithPhoneAndPin(
        phoneNumber: phoneNumber,
        pin: pin,
      );

      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      await _lockoutManager.recordFailedAttempt(phoneNumber);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> resetPin({
    required String phoneNumber,
    required String verificationId,
    required String otp,
    required String newPin,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authRepository.resetPin(
        phoneNumber: phoneNumber,
        verificationId: verificationId,
        otp: otp,
        newPin: newPin,
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearLockout() {
    state = state.copyWith(lockoutDuration: null);
  }
}

// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final phoneService = ref.watch(phoneAuthServiceProvider);
  final lockoutManager = ref.watch(lockoutManagerProvider);

  return AuthNotifier(authRepository, phoneService, lockoutManager);
});