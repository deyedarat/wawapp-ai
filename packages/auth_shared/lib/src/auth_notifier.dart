import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import 'phone_pin_auth.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService, this._firebaseAuth) : super(const AuthState()) {
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
    } catch (e) {
      if (kDebugMode) print('[AuthNotifier] Error checking PIN: $e');
    }
  }

  Future<bool> checkPhoneExists(String phone) async {
    try {
      return await _authService.phoneExists(phone);
    } catch (e) {
      if (kDebugMode) print('[AuthNotifier] Error checking phone: $e');
      return false;
    }
  }

  Future<void> sendOtp(String phone) async {
    if (state.otpStage == OtpStage.sending || state.otpStage == OtpStage.codeSent) return;
    state = state.copyWith(isLoading: true, error: null, otpStage: OtpStage.sending);
    try {
      await _authService.ensurePhoneSession(phone);
      state = state.copyWith(
        isLoading: false,
        phoneE164: phone,
        otpStage: OtpStage.codeSent,
        otpFlowActive: true,
        verificationId: _authService.lastVerificationId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString(), otpFlowActive: false);
    }
  }

  Future<void> verifyOtp(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.confirmOtp(code);
      state = state.copyWith(isLoading: false, otpFlowActive: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.setPin(pin);
      state = state.copyWith(isLoading: false, hasPin: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginByPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isValid = await _authService.verifyPin(pin);
      if (isValid) {
        state = state.copyWith(isLoading: false, hasPin: true);
      } else {
        state = state.copyWith(isLoading: false, error: 'Invalid PIN');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
