import 'package:auth_shared/auth_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/testlab_flags.dart';
import '../../../core/config/testlab_mock_data.dart';
import '../../../core/errors/auth_error_messages.dart';
import '../../../services/analytics_service.dart';
import '../../../services/driver_cleanup_service.dart';

// Provider for PhonePinAuth service singleton
final phonePinAuthServiceProvider = Provider<PhonePinAuth>((ref) {
  return PhonePinAuth(userCollection: 'drivers');
});

// Note: OtpStage and AuthState are now imported from auth_shared package

// AuthNotifier - manages authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService, this._firebaseAuth) : super(const AuthState()) {
    // Listen to Firebase auth state changes
    _authStateSubscription = _firebaseAuth.authStateChanges().listen((user) {
      if (kDebugMode) {
        print(
            '[AuthNotifier] AUTH_STATE_TRANSITION: firebase_auth_changed | user=${user?.uid}, phone=${user?.phoneNumber}');
      }

      if (user != null) {
        // New user or re-auth: reset pinStatus to unknown if it's different
        // But if user is same, we might want to keep state.
        // For safety, let's follow the prompt pattern:
        state = state.copyWith(
            user: user,
            // If strictly following new logic:
            pinStatus: PinStatus.unknown);
        _checkHasPin();
      } else {
        if (kDebugMode) {
          print('[AuthNotifier] AUTH_STATE_TRANSITION: user_signed_out | isPinResetFlow=${state.isPinResetFlow}');
        }
        // During PIN reset flow, preserve phoneE164 to avoid losing context
        if (state.isPinResetFlow) {
          state = state.copyWith(hasPin: false, pinStatus: PinStatus.unknown);
        } else {
          state = state.copyWith(hasPin: false, phoneE164: null, pinStatus: PinStatus.unknown);
        }
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

  // Public method to trigger check manually (e.g. from PinGateScreen)
  void checkHasPin() => _checkHasPin();

  // Check if current user has a PIN set
  Future<void> _checkHasPin() async {
    final user = state.user; // Use state.user or _firebaseAuth.currentUser
    if (user == null) return;

    // Prevent duplicate checks if we already have a definitive result or are loading
    // Exception: If error, we allow retry (implicit in avoiding this return)
    if (state.pinStatus == PinStatus.loading ||
        state.pinStatus == PinStatus.hasPin ||
        state.pinStatus == PinStatus.noPin) {
      return;
    }

    try {
      if (kDebugMode) {
        print('[AuthNotifier] Checking if user has PIN, isPinResetFlow=${state.isPinResetFlow}');
      }

      state = state.copyWith(isPinCheckLoading: true, pinStatus: PinStatus.loading);

      // Driver app has hasPinHash method
      final hasPinHash = await _authService.hasPinHash();

      // CRITICAL: During PIN reset flow, always report hasPin=false/noPin
      final effectiveHasPin = state.isPinResetFlow ? false : hasPinHash;

      if (kDebugMode && state.isPinResetFlow) {
        print('[AuthNotifier] PIN reset flow active - forcing hasPin=false (actual hasPinHash=$hasPinHash)');
      }

      final status = effectiveHasPin ? PinStatus.hasPin : PinStatus.noPin;

      state = state.copyWith(
        hasPin: effectiveHasPin,
        pinStatus: status,
        phoneE164: user.phoneNumber,
        isPinCheckLoading: false,
      );

      if (kDebugMode) {
        print('[AuthNotifier] _checkHasPin result: $status');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[AuthNotifier] Error checking PIN: $e');
      }
      state = state.copyWith(isPinCheckLoading: false, pinStatus: PinStatus.error);
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
    state = state.copyWith(otpFlowActive: false, isPinResetFlow: false);
    if (kDebugMode) {
      print('[AuthNotifier] OTP flow ended');
    }
  }

  // Start PIN reset flow
  void startPinResetFlow() {
    state = state.copyWith(otpFlowActive: true, isPinResetFlow: true);
    if (kDebugMode) {
      print('[AuthNotifier] PIN reset flow started');
    }
  }

  // Check if phone number exists
  Future<bool> checkPhoneExists(String phoneE164) async {
    try {
      return await _authService.phoneExists(phoneE164);
    } on Object catch (e) {
      if (kDebugMode) {
        print('[AuthNotifier] Error checking phone existence: $e');
      }
      return false;
    }
  }

  // Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    // Guard: prevent duplicate calls
    if (state.otpStage == OtpStage.sending || state.otpStage == OtpStage.codeSent) {
      if (kDebugMode) {
        print('[AuthNotifier] sendOtp blocked: already ${state.otpStage}');
      }
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      otpStage: OtpStage.sending,
      otpFlowActive: true, // MUST be set immediately
    );

    if (kDebugMode) {
      print('[AuthNotifier] DIAGNOSTIC: sendOtp() starting for phone=$phone at ${DateTime.now()}');
    }

    try {
      // Force new session if we're in PIN reset flow
      final forceNewSession = state.isPinResetFlow;
      if (kDebugMode) {
        print('[AuthNotifier] DIAGNOSTIC: forceNewSession=$forceNewSession (isPinResetFlow=${state.isPinResetFlow})');
      }

      await _authService.ensurePhoneSession(phone, forceNewSession: forceNewSession);
      if (kDebugMode) print('[AuthNotifier] DIAGNOSTIC: OTP sent successfully');
      state = state.copyWith(
        isLoading: false,
        phoneE164: phone,
        otpStage: OtpStage.codeSent,
      );
    } on Object catch (e) {
      if (kDebugMode) print('[AuthNotifier] DIAGNOSTIC: Send OTP error: ${e.runtimeType} - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        otpFlowActive: false, // End flow on error
        otpStage: OtpStage.failed,
        isPinResetFlow: false, // Clear reset flag on error
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
        print('[AuthNotifier] OTP verified, user should update via authStateChanges');
      }
      await AnalyticsService.instance.logLoginSuccess('otp');
      state = state.copyWith(
        isLoading: false,
        otpFlowActive: false,
        otpStage: OtpStage.idle,
        // Keep isPinResetFlow for now - AuthGate/OtpScreen will handle navigation
      );
      // User will be updated via authStateChanges listener
    } on Object catch (e) {
      if (kDebugMode) print('[AuthNotifier] Verify OTP error: $e');
      state = state.copyWith(
        isLoading: false,
        error: AuthErrorMessages.getErrorMessage(e),
      );
    }
  }

  // Create/set PIN for authenticated user
  Future<void> createPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.setPin(pin);
      await AnalyticsService.instance.logPinCreated();

      // CRITICAL: Clear isPinResetFlow flag after successful PIN creation
      // This allows AuthGate to navigate to home screen instead of looping back to CreatePinScreen
      if (kDebugMode) {
        print('[AuthNotifier] PIN created successfully, clearing isPinResetFlow flag');
      }

      state = state.copyWith(
        isLoading: false,
        hasPin: true,
        isPinResetFlow: false, // Clear reset flow flag
      );
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: AuthErrorMessages.getErrorMessage(e),
      );
    }
  }

  // Login by verifying PIN
  // CHANGE SIGNATURE: Add explicit phone parameter (matches client app pattern)
  Future<void> loginByPin(String pin, String phoneE164) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Use explicit parameter instead of state.phoneE164
      final isValid = await _authService.verifyPin(pin, phoneE164);
      if (isValid) {
        await AnalyticsService.instance.logLoginSuccess('pin');
        state = state.copyWith(isLoading: false, hasPin: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: AuthErrorMessages.pinIncorrect,
        );
      }
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: AuthErrorMessages.getErrorMessage(e),
      );
    }
  }

  // Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (kDebugMode) {
        print('[AuthNotifier] AUTH_STATE_TRANSITION: logout_initiated | user=${_firebaseAuth.currentUser?.uid}');
      }

      // Cleanup: stop location, set offline, clear state
      try {
        await DriverCleanupService.instance.cleanupBeforeLogout();
        if (kDebugMode) {
          print('[AuthNotifier] Driver cleanup completed');
        }
      } on Object catch (e) {
        if (kDebugMode) {
          print('[AuthNotifier] Cleanup error (continuing logout): $e');
        }
        // Continue with logout even if cleanup fails
      }

      await _authService.signOut();
      state = const AuthState(); // Reset to initial state

      if (kDebugMode) {
        print('[AuthNotifier] AUTH_STATE_TRANSITION: logout_complete | user=null, hasPin=false, otpStage=idle');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[AuthNotifier] AUTH_STATE_TRANSITION: logout_failed | error=$e');
      }
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
    // Return mock auth state for Test Lab mode
    if (TestLabFlags.safeEnabled) {
      return _MockAuthNotifier();
    }

    final authService = ref.watch(phonePinAuthServiceProvider);
    final firebaseAuth = FirebaseAuth.instance;
    return AuthNotifier(authService, firebaseAuth);
  },
);

/// Mock AuthNotifier for Test Lab mode
class _MockAuthNotifier extends AuthNotifier {
  _MockAuthNotifier()
      : super(
          PhonePinAuth(userCollection: 'drivers'),
          FirebaseAuth.instance,
        ) {
    // Override the state with mock data
    state = AuthState(
      user: TestLabMockData.mockUser,
      hasPin: true,
      phoneE164: TestLabMockData.mockDriverPhone,
      isLoading: false,
      otpFlowActive: false,
      otpStage: OtpStage.idle,
      isPinResetFlow: false,
    );
  }
}
