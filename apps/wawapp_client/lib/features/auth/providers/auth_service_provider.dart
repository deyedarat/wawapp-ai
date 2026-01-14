import 'package:auth_shared/auth_shared.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core_shared/core_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/pin_status_cache.dart';
import '../../../core/logging/auth_logger.dart';

// Provider for PhonePinAuth service singleton
final phonePinAuthServiceProvider = Provider<PhonePinAuth>((ref) {
  return PhonePinAuth(userCollection: 'users');
});

// Note: OtpStage and AuthState are now imported from auth_shared package

// AuthNotifier - manages authentication state
class ClientAuthNotifier extends StateNotifier<AuthState> {
  ClientAuthNotifier(this._authService, this._firebaseAuth) : super(const AuthState()) {
    // Listen to Firebase auth state changes
    _authStateSubscription = _firebaseAuth.authStateChanges().listen((user) {
      if (kDebugMode) {
        print(
            '[ClientAuthNotifier] Auth state changed: user=${user?.uid}, phone=${user?.phoneNumber}, isPinResetFlow=${state.isPinResetFlow}');
      }

      // When user changes, reset PinStatus to loading
      state = state.copyWith(
        user: user,
        pinStatus: user != null ? PinStatus.loading : PinStatus.unknown,
      );

      // Set user context for Crashlytics
      if (user != null) {
        CrashlyticsObserver.setUserContext(user.uid, 'client');
        checkHasPin();
      } else {
        // On logout, preserve phoneE164 if PIN reset is active
        if (state.isPinResetFlow) {
          state = state.copyWith(pinStatus: PinStatus.noPin);
        } else {
          state = state.copyWith(pinStatus: PinStatus.unknown, phoneE164: null);
        }
      }
    });
  }

  final PhonePinAuth _authService;
  final FirebaseAuth _firebaseAuth;
  late final _authStateSubscription;
  DateTime? _lastOtpSentTime;

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  // Check if current user has a PIN set
  Future<void> checkHasPin() async {
    final oldStatus = state.pinStatus;
    final user = _firebaseAuth.currentUser;

    try {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Checking if user has PIN, isPinResetFlow=${state.isPinResetFlow}');
      }

      // Try to preload from cache for faster startup
      if (user != null && oldStatus == PinStatus.unknown) {
        final cached = await PinStatusCache.get(user.uid);
        if (cached != null) {
          if (kDebugMode) {
            print('[ClientAuthNotifier] Using cached PIN status: $cached');
          }
          state = state.copyWith(pinStatus: cached);
          AuthLogger.logPinStatusChange(oldStatus.toString(), cached.toString(), user.uid);
        }
      }

      state = state.copyWith(pinStatus: PinStatus.loading);

      if (user != null) {
        final hasPinHash = await _authService.hasPinHash();

        // During PIN reset flow, force noPin to ensure router navigates to create-pin
        final effectiveStatus =
            state.isPinResetFlow ? PinStatus.noPin : (hasPinHash ? PinStatus.hasPin : PinStatus.noPin);

        if (kDebugMode && state.isPinResetFlow) {
          print('[ClientAuthNotifier] PIN reset flow active - forcing noPin (actual hasPinHash=$hasPinHash)');
        }

        if (kDebugMode) {
          print('[ClientAuthNotifier] hasPinHash=$hasPinHash, effectiveStatus=$effectiveStatus');
        }

        state = state.copyWith(
          pinStatus: effectiveStatus,
          phoneE164: user.phoneNumber,
        );

        // Cache the result for next time
        await PinStatusCache.set(user.uid, effectiveStatus);

        // Log PIN status change
        AuthLogger.logPinStatusChange(oldStatus.toString(), effectiveStatus.toString(), user.uid);
      } else {
        state = state.copyWith(pinStatus: PinStatus.unknown);
        AuthLogger.logPinStatusChange(oldStatus.toString(), PinStatus.unknown.toString(), null);
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Error checking PIN: $e');
      }

      // On error, try to use cached value as fallback
      if (user != null) {
        final cached = await PinStatusCache.get(user.uid);
        if (cached != null) {
          if (kDebugMode) {
            print('[ClientAuthNotifier] Network error, using cached PIN status: $cached');
          }
          state = state.copyWith(pinStatus: cached);
          AuthLogger.logPinStatusChange(oldStatus.toString(), cached.toString(), user.uid);
          return;
        }
      }

      state = state.copyWith(pinStatus: PinStatus.error);
      AuthLogger.logPinStatusChange(oldStatus.toString(), PinStatus.error.toString(), user?.uid);
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
    state = state.copyWith(otpFlowActive: false, isPinResetFlow: false);
    if (kDebugMode) {
      print('[ClientAuthNotifier] OTP flow ended');
    }
  }

  // Start PIN reset flow
  void startPinResetFlow() {
    state = state.copyWith(otpFlowActive: true, isPinResetFlow: true);
    if (kDebugMode) {
      print('[ClientAuthNotifier] PIN reset flow started');
    }
  }

  // Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    // RATE LIMIT CHECK: Client-side cooldown (60 seconds)
    if (_lastOtpSentTime != null) {
      final difference = DateTime.now().difference(_lastOtpSentTime!);
      if (difference < const Duration(seconds: 60)) {
        final remaining = 60 - difference.inSeconds;
        state = state.copyWith(
          error: 'يرجى الانتظار $remaining ثانية قبل إعادة المحاولة',
          isLoading: false,
        );
        if (kDebugMode) {
          print('[ClientAuthNotifier] sendOtp rate limited. Remaining: ${remaining}s');
        }
        return;
      }
    }

    // Guard: prevent duplicate calls
    if (state.otpStage == OtpStage.sending || state.otpStage == OtpStage.codeSent) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] sendOtp blocked: already ${state.otpStage}');
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
        final maskedPhone =
            phone.length > 5 ? '${phone.substring(0, 3)}...${phone.substring(phone.length - 2)}' : '***';
        print('[ClientAuthNotifier] Sending OTP to $maskedPhone');
      }
      await _authService.ensurePhoneSession(phone);
      final verificationId = _authService.lastVerificationId;
      if (kDebugMode) {
        print('[ClientAuthNotifier] OTP sent successfully, verificationId=$verificationId');
      }

      // Update last sent time on success
      _lastOtpSentTime = DateTime.now();

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
        isPinResetFlow: false, // Clear reset flag on error
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
        print('[ClientAuthNotifier] OTP verified, user should update via authStateChanges');
      }
      state = state.copyWith(
        isLoading: false,
        otpFlowActive: false,
        otpStage: OtpStage.idle,
        // Keep isPinResetFlow for now - router will handle navigation
      );
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
      if (kDebugMode) {
        print('[ClientAuthNotifier] PIN created successfully, clearing isPinResetFlow flag');
      }

      final user = _firebaseAuth.currentUser;
      state = state.copyWith(
        isLoading: false,
        pinStatus: PinStatus.hasPin,
        isPinResetFlow: false, // Clear reset flow flag
      );

      // Cache the new PIN status
      if (user != null) {
        await PinStatusCache.set(user.uid, PinStatus.hasPin);
      }
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
          print('[ClientAuthNotifier] PIN verified, user signed in successfully');
        }
        state = state.copyWith(
          isLoading: false,
          pinStatus: PinStatus.hasPin,
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
      state = state.copyWith(pinStatus: PinStatus.hasPin);
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

      // Clear PIN status cache
      await PinStatusCache.clearAll();

      await _authService.signOut();
      state = const AuthState(); // Reset to initial state (clears isPinResetFlow)
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
        isPinResetFlow: false,
      );
    }
  }

  /// Delete Account - Google Play Compliance (Account Deletion Requirement 2024-2025)
  ///
  /// This is a DESTRUCTIVE operation that permanently deletes:
  /// - Firebase Authentication user
  /// - Firestore user document
  /// - All associated user data
  ///
  /// This action CANNOT be undone.
  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('لا يوجد مستخدم مسجل دخول');
      }

      if (kDebugMode) {
        print('[ClientAuthNotifier] Deleting account for user: ${user.uid}');
      }

      // Call Cloud Function to delete server-side data
      final callable = FirebaseFunctions.instance.httpsCallable('deleteAccount');
      final result = await callable.call();

      // Validate response
      if (result.data['ok'] != true) {
        throw Exception('فشل حذف الحساب من الخادم');
      }

      if (kDebugMode) {
        print('[ClientAuthNotifier] Account deleted successfully from server');
      }

      // Clear PIN status cache
      await PinStatusCache.clearAll();

      // Reset to initial state
      // Note: Firebase Auth will automatically sign out after server deletes the auth account
      state = const AuthState();

      if (kDebugMode) {
        print('[ClientAuthNotifier] Account deletion complete');
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Delete account error (Firebase): ${e.code} - ${e.message}');
      }
      state = state.copyWith(
        isLoading: false,
        error: 'فشل حذف الحساب: ${e.message ?? e.code}',
      );
      rethrow;
    } on Object catch (e) {
      if (kDebugMode) {
        print('[ClientAuthNotifier] Delete account error: $e');
      }
      state = state.copyWith(
        isLoading: false,
        error: 'فشل حذف الحساب: ${e.toString()}',
      );
      rethrow;
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
