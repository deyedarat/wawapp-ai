import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/entities/user_entity.dart';
import '../services/phone_auth_service.dart';
import '../utils/lockout_manager.dart';

// Auth State
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
    bool clearError = false,
    bool clearLockout = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lockoutDuration: clearLockout ? null : (lockoutDuration ?? this.lockoutDuration),
    );
  }

  bool get isAuthenticated => user != null;
  bool get hasError => error != null;
  bool get isLocked => lockoutDuration != null;
  bool get hasVerificationId => verificationId != null;
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final PhoneAuthService _phoneService;
  final LockoutManager _lockoutManager;

  AuthNotifier(
    this._authRepository,
    this._phoneService,
    this._lockoutManager,
  ) : super(const AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(user: user);
      }
    } catch (_) {}
  }

  Future<void> sendOTP(String phoneNumber) async {
    if (!PhoneAuthService.isValidPhoneNumber(phoneNumber)) {
      state = state.copyWith(error: 'Invalid phone number format');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

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
    required AccountType accountType,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

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
    state = state.copyWith(isLoading: true, clearError: true);

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
    state = state.copyWith(isLoading: true, clearError: true);

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
    state = state.copyWith(clearError: true);
  }

  void clearLockout() {
    state = state.copyWith(clearLockout: true);
  }
}
