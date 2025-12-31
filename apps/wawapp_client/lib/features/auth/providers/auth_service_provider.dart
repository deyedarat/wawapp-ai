import 'package:auth_shared/auth_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/observability/crashlytics_observer.dart';

// Provider for PhonePinAuth service singleton
final phonePinAuthServiceProvider = Provider<PhonePinAuth>((ref) {
  return PhonePinAuth(userCollection: 'users');
});

// Note: OtpStage and AuthState are now imported from auth_shared package

// AuthNotifier - manages authentication state
class ClientAuthNotifier extends StateNotifier<AuthState> {
  ClientAuthNotifier(this._authService, this._firebaseAuth)
      : super(const AuthState()) {
    // Listen to Firebase auth state changes
    _authStateSubscription = _firebaseAuth.authStateChanges().listen((user) {
      if (kDebugMode) {
        print(
            '[ClientAuthNotifier] Auth state changed: user=${user?.uid}, phone=${user?.phoneNumber}');
      }
      state = state.copyWith(user: user);

      // Set user context for Crashlytics
      if (user != null) {
        CrashlyticsObserver.setUserContext(user.uid, 'client');
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

  // Check if current user has a PIN set
  Future<void> _checkHasPin() async {
    try {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Checking if user has PIN');
      }
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final hasPinHash = await _authService.hasPinHash();
        if (kDebugMode) {
          print('[ClientAuthNotifier] hasPinHash=$hasPinHash');
        }
        state = state.copyWith(
          hasPin: hasPinHash,
          phoneE164: user.phoneNumber,
        );
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Error checking PIN: $e');
      }
      // Silent fail - hasPin will remain false
    }
  }

  // Start OTP flow
  void startOtpFlow() {
    state = state.copyWith(otpFlowActive: true);
    if (kDebugMode) {
      print('[ClientAuthNotifier] OTP flow started');
    }
  }

  // End OTP flow
  void endOtpFlow() {
    state = state.copyWith(otpFlowActive: false);
    if (kDebugMode) {
      print('[ClientAuthNotifier] OTP flow ended');
    }
  }

  // Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    // Guard: prevent duplicate calls
    if (state.otpStage == OtpStage.sending ||
        state.otpStage == OtpStage.codeSent) {
      if (kDebugMode) {
        print(
            '[ClientAuthNotifier] sendOtp blocked: already ${state.otpStage}');
      }
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      otpStage: OtpStage.sending,
      otpFlowActive: true, // MUST be set immediately
    );
    try {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Sending OTP to $phone');
      }
      await _authService.ensurePhoneSession(phone);
      final verificationId = _authService.lastVerificationId;
      if (kDebugMode) {
        print(
            '[ClientAuthNotifier] OTP sent successfully, verificationId=$verificationId');
      }
      state = state.copyWith(
        isLoading: false,
        phoneE164: phone,
        otpStage: OtpStage.codeSent,
        verificationId: verificationId,
      );
    } on Object catch (e) {
      if (kDebugMode) print('[ClientAuthNotifier] Send OTP error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        otpFlowActive: false, // End flow on error
        otpStage: OtpStage.failed,
      );
    }
  }

  // Verify OTP code
  Future<void> verifyOtp(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Verifying OTP code');
      }
      await _authService.confirmOtp(code);
      if (kDebugMode) {
        print(
            '[ClientAuthNotifier] OTP verified, user should update via authStateChanges');
      }
      state = state.copyWith(isLoading: false, otpFlowActive: false);
      // User will be updated via authStateChanges listener
    } on Object catch (e) {
      if (kDebugMode) print('[ClientAuthNotifier] Verify OTP error: $e');
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
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Check if a phone number exists in the system
  Future<bool> checkPhoneExists(String phoneE164) async {
    try {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Checking if phone exists: $phoneE164');
      }
      final exists = await _authService.phoneExists(phoneE164);
      if (kDebugMode) {
        print('[ClientAuthNotifier] Phone exists: $exists');
      }
      return exists;
    } on Object catch (e) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Error checking phone: $e');
      }
      return false;
    }
  }

  // Login by verifying PIN
  Future<void> loginByPin(String pin, String phoneE164) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Attempting PIN login for $phoneE164');
      }

      final isValid = await _authService.verifyPin(pin, phoneE164);

      if (isValid) {
        // PIN verified successfully, user is now signed in with custom token
        // The authStateChanges listener will update the state automatically
        if (kDebugMode) {
          print(
              '[ClientAuthNotifier] PIN verified, user signed in successfully');
        }
        state = state.copyWith(
          isLoading: false,
          hasPin: true,
          phoneE164: phoneE164,
        );
      } else {
        if (kDebugMode) {
          print('[ClientAuthNotifier] PIN verification failed');
        }
        state = state.copyWith(
          isLoading: false,
          error: 'PIN غير صحيح',
        );
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] PIN login error: $e');
      }
      state = state.copyWith(
        isLoading: false,
        error: 'خطأ في تسجيل الدخول: ${e.toString()}',
      );
    }
  }

  // Verify current PIN (for PIN change flow)
  Future<bool> verifyCurrentPin(String pin) async {
    try {
      final phoneE164 = _firebaseAuth.currentUser?.phoneNumber;
      if (phoneE164 == null) {
        if (kDebugMode) {
          print('[ClientAuthNotifier] Cannot verify PIN: no phone number');
        }
        return false;
      }

      if (kDebugMode) {
        print('[ClientAuthNotifier] Verifying current PIN');
      }

      // Use verifyPin but don't sign in again (user is already signed in)
      final isValid = await _authService.verifyPin(pin, phoneE164);
      return isValid;
    } on Object catch (e) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Error verifying current PIN: $e');
      }
      return false;
    }
  }

  // Set new PIN (for PIN change flow)
  Future<void> setPin(String pin) async {
    try {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Setting new PIN');
      }
      await _authService.setPin(pin);
      state = state.copyWith(hasPin: true);
    } on Object catch (e) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Error setting PIN: $e');
      }
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Logging out user');
      }
      await _authService.signOut();
      state = const AuthState(); // Reset to initial state
      if (kDebugMode) {
        print('[ClientAuthNotifier] Logout complete');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Logout error: $e');
      }
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

// Main auth provider - keepAlive to preserve state across navigation
final authProvider = StateNotifierProvider<ClientAuthNotifier, AuthState>(
  (ref) {
    final authService = ref.watch(phonePinAuthServiceProvider);
    final firebaseAuth = FirebaseAuth.instance;
    return ClientAuthNotifier(authService, firebaseAuth);
  },
);
