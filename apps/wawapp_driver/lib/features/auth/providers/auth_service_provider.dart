import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auth_shared/auth_shared.dart';
import '../../../services/analytics_service.dart';
import '../../../services/driver_cleanup_service.dart';
import '../../../core/config/testlab_flags.dart';
import '../../../core/config/testlab_mock_data.dart';

// Provider for PhonePinAuth service singleton
final phonePinAuthServiceProvider = Provider<PhonePinAuth>((ref) {
  return PhonePinAuth(userCollection: 'drivers');
});

// Note: OtpStage and AuthState are now imported from auth_shared package

// AuthNotifier - manages authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService, this._firebaseAuth)
      : super(const AuthState()) {
    // Listen to Firebase auth state changes
    _authStateSubscription = _firebaseAuth.authStateChanges().listen((user) {
      if (kDebugMode) {
        print(
            '[AuthNotifier] AUTH_STATE_TRANSITION: firebase_auth_changed | user=${user?.uid}, phone=${user?.phoneNumber}');
      }
      state = state.copyWith(user: user);
      if (user != null) {
        _checkHasPin();
      } else {
        if (kDebugMode) {
          print('[AuthNotifier] AUTH_STATE_TRANSITION: user_signed_out | setting hasPin=false, phoneE164=null');
        }
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
          phoneE164: user.phoneNumber,
        );
      }
    } on Object catch (e) {
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
        isLoading: true, error: null, otpStage: OtpStage.sending);
    try {
      if (kDebugMode) {
        print('[AuthNotifier] Sending OTP to $phone');
      }
      await _authService.ensurePhoneSession(phone);
      if (kDebugMode) print('[AuthNotifier] OTP sent successfully');
      state = state.copyWith(
        isLoading: false,
        phoneE164: phone,
        otpStage: OtpStage.codeSent,
      );
    } on Object catch (e) {
      if (kDebugMode) print('[AuthNotifier] Send OTP error: $e');
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
        print('[AuthNotifier] Verifying OTP code');
      }
      await _authService.confirmOtp(code);
      if (kDebugMode) {
        print(
            '[AuthNotifier] OTP verified, user should update via authStateChanges');
      }
      await AnalyticsService.instance.logLoginSuccess('otp');
      state = state.copyWith(isLoading: false, otpFlowActive: false);
      // User will be updated via authStateChanges listener
    } on Object catch (e) {
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
      await AnalyticsService.instance.logPinCreated();
      state = state.copyWith(isLoading: false, hasPin: true);
    } on Object catch (e) {
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
        await AnalyticsService.instance.logLoginSuccess('pin');
        state = state.copyWith(isLoading: false, hasPin: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid PIN',
        );
      }
    } on Object catch (e) {
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
  _MockAuthNotifier() : super(
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
    );
  }
}
