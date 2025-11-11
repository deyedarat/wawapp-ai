import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final bool otpFlowActive; // Track OTP flow across rebuilds
  final OtpStage otpStage;
  final String? verificationId;
  final int? resendToken;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.phone,
    this.hasPin = false,
    this.error,
    this.otpFlowActive = false,
    this.otpStage = OtpStage.idle,
    this.verificationId,
    this.resendToken,
  });

  AuthState copyWith({
    bool? isLoading,
    User? user,
    String? phone,
    bool? hasPin,
    String? error,
    bool? otpFlowActive,
    OtpStage? otpStage,
    String? verificationId,
    int? resendToken,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      phone: phone ?? this.phone,
      hasPin: hasPin ?? this.hasPin,
      error: error,
      otpFlowActive: otpFlowActive ?? this.otpFlowActive,
      otpStage: otpStage ?? this.otpStage,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
    );
  }
}

// AuthNotifier - manages authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService, this._firebaseAuth)
      : super(const AuthState()) {
    // Listen to Firebase auth state changes
    _authStateSubscription = _firebaseAuth.authStateChanges().listen((user) {
      if (kDebugMode) {
        print(
            '[AuthNotifier] Auth state changed: user=${user?.uid}, phone=${user?.phoneNumber}');
      }
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
  late final _authStateSubscription;

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  // Check if current user has a PIN set
  Future<void> _checkHasPin() async {
    try {
      if (kDebugMode) {
        print('[AuthNotifier] Checking if user has PIN');
      }
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        // Driver app has hasPinHash method
        final hasPinHash = await _authService.hasPinHash();
        if (kDebugMode) {
          print('[AuthNotifier] hasPinHash=$hasPinHash');
        }
        state = state.copyWith(
          hasPin: hasPinHash,
          phone: user.phoneNumber,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AuthNotifier] Error checking PIN: $e');
      }
      // Silent fail - hasPin will remain false
    }
  }

  // Start OTP flow
  void startOtpFlow() {
    state = state.copyWith(otpFlowActive: true);
    if (kDebugMode) {
      print('[AuthNotifier] OTP flow started');
    }
  }

  // End OTP flow
  void endOtpFlow() {
    state = state.copyWith(otpFlowActive: false);
    if (kDebugMode) {
      print('[AuthNotifier] OTP flow ended');
    }
  }

  // Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    // Guard: prevent duplicate calls
    if (state.otpStage == OtpStage.sending ||
        state.otpStage == OtpStage.codeSent) {
      if (kDebugMode) {
        print('[AuthNotifier] sendOtp blocked: already ${state.otpStage}');
      }
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      otpFlowActive: true,
      otpStage: OtpStage.sending,
      phone: phone,
    );

    try {
      if (kDebugMode) {
        print('[AuthNotifier] Sending OTP to $phone');
      }
      await _authService.ensurePhoneSession(
        phone,
        onCodeSent: (verificationId, resendToken) {
          if (kDebugMode) {
            print(
                '[AuthNotifier] ✅ codeSent callback → otpStage=codeSent, vid=${verificationId.substring(verificationId.length - 6)}');
          }
          state = state.copyWith(
            otpFlowActive: true,
            verificationId: verificationId,
            resendToken: resendToken,
            isLoading: false,
            error: null,
            otpStage: OtpStage.codeSent,
            phone: phone,
          );
        },
        onVerificationFailed: (errorMessage) {
          if (kDebugMode) {
            print('[AuthNotifier] ❌ verificationFailed → $errorMessage');
          }
          state = state.copyWith(
            isLoading: false,
            error: errorMessage,
            otpFlowActive: false,
            otpStage: OtpStage.failed,
          );
        },
      );
      // ✅ لا تكتب فوق الحالة هنا - callbacks تتولى التحديث
    } catch (e) {
      if (kDebugMode) print('[AuthNotifier] Send OTP error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        otpFlowActive: false,
        otpStage: OtpStage.failed,
      );
    }
  }

  // Verify OTP code
  Future<void> verifyOtp(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (kDebugMode) {
        print('[AuthNotifier] Verifying OTP code');
      }
      await _authService.confirmOtp(code);
      if (kDebugMode) {
        print(
            '[AuthNotifier] OTP verified, user should update via authStateChanges');
      }
      state = state.copyWith(isLoading: false, otpFlowActive: false);
      // User will be updated via authStateChanges listener
    } catch (e) {
      if (kDebugMode) print('[AuthNotifier] Verify OTP error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
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

// Main auth provider - keepAlive to preserve state across navigation
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) {
    final authService = ref.watch(phonePinAuthServiceProvider);
    final firebaseAuth = FirebaseAuth.instance;
    return AuthNotifier(authService, firebaseAuth);
  },
);
