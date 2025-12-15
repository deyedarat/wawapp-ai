import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import 'phone_pin_auth.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService, this._firebaseAuth)
      : super(const AuthState()) {
    _authStateSubscription = _firebaseAuth.authStateChanges().listen((user) {
      state = state.copyWith(user: user);
      if (user != null) {
        _checkHasPin();
      } else {
        state = state.copyWith(hasPin: false, phoneE164: null);
      }
    });
  }

  final PhonePinAuth _authService;
  final FirebaseAuth _firebaseAuth;
  late final _authStateSubscription;

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkHasPin() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final hasPinHash = await _authService.hasPinHash();
        state = state.copyWith(hasPin: hasPinHash, phoneE164: user.phoneNumber);
      }
    } on Object catch (e) {
      if (kDebugMode) print('[AuthNotifier] Error checking PIN: $e');
    }
  }

  Future<bool> checkPhoneExists(String phone) async {
    try {
      return await _authService.phoneExists(phone);
    } on Object catch (e) {
      if (kDebugMode) print('[AuthNotifier] Error checking phone: $e');
      return false;
    }
  }

  Future<void> sendOtp(String phone) async {
    if (kDebugMode) {
      print('[AuthNotifier] sendOtp() called');
    }

    if (state.otpStage == OtpStage.sending ||
        state.otpStage == OtpStage.codeSent) {
      if (kDebugMode) {
        print(
          '[AuthNotifier] sendOtp() aborted - already in stage ${state.otpStage}',
        );
      }
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      otpStage: OtpStage.sending,
    );
    if (kDebugMode) {
      print('[AuthNotifier] OTP stage set to sending');
    }

    try {
      if (kDebugMode) {
        print('[AuthNotifier] Calling ensurePhoneSession()');
      }
      await _authService.ensurePhoneSession(phone);

      state = state.copyWith(
        isLoading: false,
        phoneE164: phone,
        otpStage: OtpStage.codeSent,
        otpFlowActive: true,
        verificationId: _authService.lastVerificationId,
      );

      if (kDebugMode) {
        print(
          '[AuthNotifier] ensurePhoneSession() completed, state: otpStage=${state.otpStage}, otpFlowActive=${state.otpFlowActive}',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(
          '[AuthNotifier] ensurePhoneSession() FAILED: ${e.runtimeType} - $e',
        );
        print('[AuthNotifier] Stacktrace: $stackTrace');
      }

      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        otpFlowActive: false,
      );

      if (kDebugMode) {
        print(
          '[AuthNotifier] State after error: otpStage=${state.otpStage}, otpFlowActive=${state.otpFlowActive}, error=${state.error}',
        );
      }
    }
  }

  Future<void> verifyOtp(String code) async {
    if (kDebugMode) {
      print('[AuthNotifier] verifyOtp() called');
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      if (kDebugMode) {
        print('[AuthNotifier] Calling confirmOtp...');
      }

      await _authService.confirmOtp(code);

      if (kDebugMode) {
        print('[AuthNotifier] confirmOtp successful, updating state');
      }

      state = state.copyWith(isLoading: false, otpFlowActive: false);
    } on Object catch (e, stackTrace) {
      if (kDebugMode) {
        print('[AuthNotifier] verifyOtp FAILED: ${e.runtimeType} - $e');
        print('[AuthNotifier] Stacktrace: $stackTrace');
      }

      // Extract user-friendly error message
      String errorMessage = e.toString();
      if (errorMessage.contains('invalid-verification-code')) {
        errorMessage = 'Invalid verification code. Please check and try again.';
      } else if (errorMessage.contains('session-expired')) {
        errorMessage = 'Verification session expired. Please request a new code.';
      } else if (errorMessage.contains('No verification id')) {
        errorMessage = 'No verification session found. Please request a new code.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
    }
  }

  Future<void> createPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.setPin(pin);
      state = state.copyWith(isLoading: false, hasPin: true);
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginByPin(String pin, String phoneE164) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // First authenticate with phone to get user context
      await _authService.ensurePhoneSession(phoneE164);
      
      // Wait for authentication to complete, then verify PIN
      // This will be handled by the auth state listener
      state = state.copyWith(
        otpStage: OtpStage.codeSent,
        otpFlowActive: true,
        phoneE164: phoneE164,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.signOut();
      state = const AuthState();
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
