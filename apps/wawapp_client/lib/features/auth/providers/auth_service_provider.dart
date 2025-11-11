import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/phone_pin_auth.dart';

// Provider for PhonePinAuth service singleton
final phonePinAuthServiceProvider = Provider<PhonePinAuth>((ref) {
  return PhonePinAuth.instance;
});

// OTP Stage enum
enum OtpStage {
  idle,
  sending,
  codeSent,
  verifying,
  verified,
  failed,
}

// AuthState model
class AuthState {
  final bool isLoading;
  final User? user;
  final String? phone;
  final bool hasPin;
  final String? error;
  final bool otpFlowActive;
  final String? verificationId;
  final OtpStage otpStage;
  final int? resendToken;
  final String? phoneE164;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.phone,
    this.hasPin = false,
    this.error,
    this.otpFlowActive = false,
    this.verificationId,
    this.otpStage = OtpStage.idle,
    this.resendToken,
    this.phoneE164,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    User? user,
    String? phone,
    bool? hasPin,
    String? error,
    bool? otpFlowActive,
    String? verificationId,
    OtpStage? otpStage,
    int? resendToken,
    String? phoneE164,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      phone: phone ?? this.phone,
      hasPin: hasPin ?? this.hasPin,
      error: error,
      otpFlowActive: otpFlowActive ?? this.otpFlowActive,
      verificationId: verificationId ?? this.verificationId,
      otpStage: otpStage ?? this.otpStage,
      resendToken: resendToken ?? this.resendToken,
      phoneE164: phoneE164 ?? this.phoneE164,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// AuthNotifier - manages authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService, this._firebaseAuth)
      : super(const AuthState()) {
    // Listen to Firebase auth state changes
    _authStateSubscription = _firebaseAuth.authStateChanges().listen((user) {
      state = state.copyWith(user: user);
      if (user != null) {
        _checkHasPin();
      } else {
        state = state.copyWith(hasPin: false, phone: null);
      }
    });
  }

  final PhonePinAuth _authService;
  final FirebaseAuth _firebaseAuth;
  late final StreamSubscription<User?> _authStateSubscription;

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  // Check if current user has a PIN set
  Future<void> _checkHasPin() async {
    try {
      // For client app, check if pinHash exists in Firestore
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        // We'll infer hasPin by attempting to get user doc
        // Since client app doesn't have hasPinHash method, we'll set based on verification
        state = state.copyWith(phone: user.phoneNumber);
      }
    } catch (e) {
      // Silent fail - hasPin will remain false
    }
  }

  // Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    // Guard: prevent duplicate calls
    if (state.otpStage == OtpStage.sending ||
        state.otpStage == OtpStage.codeSent) {
      debugPrint('[AuthNotifier] sendOtp blocked: already ${state.otpStage}');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      otpFlowActive: true,
      otpStage: OtpStage.sending,
      phoneE164: phone,
      errorMessage: null,
    );

    try {
      await _authService.ensurePhoneSession(
        phone,
        onCodeSent: (verificationId, resendToken) {
          debugPrint(
              '[AuthNotifier] ✅ codeSent callback → otpStage=codeSent, vid=${verificationId.substring(verificationId.length - 6)}');
          state = state.copyWith(
            otpFlowActive: true,
            verificationId: verificationId,
            resendToken: resendToken,
            isLoading: false,
            error: null,
            otpStage: OtpStage.codeSent,
            phoneE164: phone,
            errorMessage: null,
          );
        },
        onVerificationFailed: (errorMessage) {
          debugPrint('[AuthNotifier] ❌ verificationFailed → $errorMessage');
          state = state.copyWith(
            isLoading: false,
            error: errorMessage,
            otpFlowActive: false,
            otpStage: OtpStage.failed,
            errorMessage: errorMessage,
          );
        },
      );
      // ✅ لا تكتب فوق الحالة هنا - callbacks تتولى التحديث
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        otpFlowActive: false,
        otpStage: OtpStage.failed,
        errorMessage: e.toString(),
      );
    }
  }

  // Verify OTP code
  Future<void> verifyOtp(String code) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      otpStage: OtpStage.verifying,
    );
    try {
      await _authService.confirmOtp(code);
      state = state.copyWith(
        isLoading: false,
        otpFlowActive: false,
        verificationId: null,
        otpStage: OtpStage.verified,
      );
      // User will be updated via authStateChanges listener
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        otpFlowActive: false,
        otpStage: OtpStage.failed,
        errorMessage: e.toString(),
      );
    }
  }

  // Create/set PIN for authenticated user
  Future<void> createPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.setPin(pin);
      state = state.copyWith(isLoading: false, hasPin: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Login by verifying PIN
  Future<void> loginByPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isValid = await _authService.verifyPin(pin);
      if (isValid) {
        state = state.copyWith(isLoading: false, hasPin: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid PIN',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.signOut();
      state = const AuthState(); // Reset to initial state
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

// Main auth provider - auto dispose when no longer used
final authProvider = StateNotifierProvider.autoDispose<AuthNotifier, AuthState>(
  (ref) {
    final authService = ref.watch(phonePinAuthServiceProvider);
    final firebaseAuth = FirebaseAuth.instance;
    return AuthNotifier(authService, firebaseAuth);
  },
);
