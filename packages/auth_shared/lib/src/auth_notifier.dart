import 'package:cloud_functions/cloud_functions.dart';
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
      state = state.copyWith(isPinCheckLoading: true);
      if (kDebugMode) print('[AuthNotifier] Checking if user has PIN');

      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final hasPinHash = await _authService.hasPinHash();
        if (kDebugMode) print('[AuthNotifier] hasPinHash=$hasPinHash');
        state = state.copyWith(
          hasPin: hasPinHash,
          phoneE164: user.phoneNumber,
          isPinCheckLoading: false,
        );
      } else {
        state = state.copyWith(isPinCheckLoading: false);
      }
    } on Object catch (e) {
      if (kDebugMode) print('[AuthNotifier] Error checking PIN: $e');
      state = state.copyWith(isPinCheckLoading: false);
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
    if (kDebugMode) print('[AuthNotifier] sendOtp() called with phone=$phone');

    if (state.otpStage == OtpStage.sending ||
        state.otpStage == OtpStage.codeSent) {
      if (kDebugMode)
        print(
            '[AuthNotifier] sendOtp() aborted - already in stage ${state.otpStage}');
      return;
    }

    state = state.copyWith(
      isStreamsSafeToRun: false,
      isLoading: true,
      error: null,
      otpStage: OtpStage.sending,
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      if (kDebugMode)
        print('[AuthNotifier] Calling ensurePhoneSession() for phone=$phone');
      await _authService.ensurePhoneSession(phone);

      state = state.copyWith(
        isLoading: false,
        phoneE164: phone,
        otpStage: OtpStage.codeSent,
        otpFlowActive: true,
      );

      if (kDebugMode) print('[AuthNotifier] ensurePhoneSession() completed');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(
            '[AuthNotifier] ensurePhoneSession() FAILED: ${e.runtimeType} - $e');
        print('[AuthNotifier] Stacktrace: $stackTrace');
      }
      // CRITICAL FIX: Reset otpStage to failed when CAPTCHA fails
      // This prevents the router from thinking we're still sending
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        otpStage: OtpStage.failed, // ADDED: Reset stage to failed
        otpFlowActive: false,
        isStreamsSafeToRun: true,
      );
    }
  }

  Future<void> verifyOtp(String code) async {
    if (kDebugMode) print('[AuthNotifier] verifyOtp() called');
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.confirmOtp(code);
      state = state.copyWith(
        isLoading: false,
        otpFlowActive: false,
        isStreamsSafeToRun: true,
      );
    } on Object catch (e) {
      if (kDebugMode)
        print('[AuthNotifier] verifyOtp FAILED: ${e.runtimeType} - $e');

      String errorMessage = e.toString();
      if (e is FirebaseFunctionsException) {
        if (e.code == 'invalid-argument') {
          errorMessage = 'رمز التحقق غير صحيح، يرجى المحاولة مجدداً.';
        } else if (e.code == 'resource-exhausted') {
          errorMessage = 'تجاوزت عدد المحاولات المسموح بها، يرجى الانتظار.';
        } else {
          errorMessage = 'حدث خطأ أثناء التحقق، يرجى المحاولة مجدداً.';
        }
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

  // ✅ loginByPin: يستخدم PIN مباشرة عبر Cloud Function - لا يرسل OTP
  Future<void> loginByPin(String pin, String phoneE164) async {
    if (kDebugMode)
      print('[AuthNotifier] loginByPin() called for phone=$phoneE164');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _authService.verifyPin(pin, phoneE164);

      if (success) {
        if (kDebugMode) print('[AuthNotifier] loginByPin() success');
        state = state.copyWith(
          isLoading: false,
          phoneE164: phoneE164,
          isStreamsSafeToRun: true,
        );
      } else {
        if (kDebugMode) print('[AuthNotifier] loginByPin() failed - wrong PIN');
        state = state.copyWith(
          isLoading: false,
          error: 'رقم السري غير صحيح، يرجى المحاولة مجدداً.',
        );
      }
    } on Object catch (e) {
      if (kDebugMode) print('[AuthNotifier] loginByPin() exception: $e');
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
