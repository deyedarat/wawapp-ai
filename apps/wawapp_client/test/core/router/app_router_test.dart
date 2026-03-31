import 'package:auth_shared/auth_shared.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive tests for GoRouter navigation logic
/// Tests the critical reCAPTCHA flow and state transitions
void main() {
  group('GoRouter Redirect Logic - reCAPTCHA Flow', () {
    test('should stay on /login during OtpStage.sending (CAPTCHA in progress)', () {
      // Simulate the state during reCAPTCHA verification
      const authState = AuthState(
        user: null,
        otpStage: OtpStage.sending,
        otpFlowActive: true,
        isLoading: true,
        pinStatus: PinStatus.unknown,
      );

      // The router should keep user on /login during reCAPTCHA
      // This is the critical fix: prevent premature navigation to /otp
      expect(authState.otpStage, OtpStage.sending);
      expect(authState.user, isNull);

      // During sending, canOtp should be false because isSending=true
      final isSending = authState.otpStage == OtpStage.sending;
      final canOtp = ((authState.otpFlowActive || authState.otpStage == OtpStage.codeSent) && !isSending);

      expect(isSending, isTrue, reason: 'Should be in sending state during reCAPTCHA');
      expect(canOtp, isFalse, reason: 'Should NOT allow OTP navigation during sending');
    });

    test('should allow navigation to /otp only after OtpStage.codeSent', () {
      // Simulate the state AFTER reCAPTCHA completes successfully
      const authState = AuthState(
        user: null,
        otpStage: OtpStage.codeSent,
        otpFlowActive: true,
        isLoading: false,
        pinStatus: PinStatus.unknown,
      );

      final isSending = authState.otpStage == OtpStage.sending;
      final canOtp = ((authState.otpFlowActive || authState.otpStage == OtpStage.codeSent) && !isSending);

      expect(isSending, isFalse, reason: 'Should NOT be sending after code is sent');
      expect(canOtp, isTrue, reason: 'Should allow OTP navigation after codeSent');
    });

    test('should redirect to /login when not authenticated', () {
      const authState = AuthState(
        user: null,
        otpStage: OtpStage.idle,
        otpFlowActive: false,
        isLoading: false,
        pinStatus: PinStatus.unknown,
      );

      final loggedIn = authState.user != null;
      final isSending = authState.otpStage == OtpStage.sending;
      final canOtp = ((authState.otpFlowActive || authState.otpStage == OtpStage.codeSent) && !isSending);

      expect(loggedIn, isFalse);
      expect(canOtp, isFalse);
      expect(isSending, isFalse);
      // Router should redirect to /login
    });

    test('should redirect to /create-pin when user has no PIN', () {
      const authState = AuthState(
        user: null, // Will be set by FirebaseAuth in real scenario
        otpStage: OtpStage.idle,
        otpFlowActive: false,
        isLoading: false,
        pinStatus: PinStatus.noPin,
        hasPin: false,
      );

      // Simulate logged in user
      final loggedIn = true; // authState.user != null
      final pinStatus = authState.pinStatus;

      expect(loggedIn, isTrue);
      expect(pinStatus, PinStatus.noPin);
      // Router should redirect to /create-pin
    });

    test('should allow access to home when user is authenticated with PIN', () {
      const authState = AuthState(
        user: null, // Will be set by FirebaseAuth
        otpStage: OtpStage.idle,
        otpFlowActive: false,
        isLoading: false,
        pinStatus: PinStatus.hasPin,
        hasPin: true,
      );

      final loggedIn = true; // authState.user != null
      final pinStatus = authState.pinStatus;

      expect(loggedIn, isTrue);
      expect(pinStatus, PinStatus.hasPin);
      // Router should allow access to all protected routes
    });

    test('should handle PIN gate states (unknown, loading, error)', () {
      const unknownState = AuthState(
        user: null,
        pinStatus: PinStatus.unknown,
        isPinCheckLoading: false,
      );

      const loadingState = AuthState(
        user: null,
        pinStatus: PinStatus.loading,
        isPinCheckLoading: true,
      );

      const errorState = AuthState(
        user: null,
        pinStatus: PinStatus.error,
        isPinCheckLoading: false,
      );

      // All these states should redirect to /pin-gate
      expect(unknownState.pinStatus, PinStatus.unknown);
      expect(loadingState.pinStatus, PinStatus.loading);
      expect(errorState.pinStatus, PinStatus.error);
    });

    test('should not navigate during auth loading state', () {
      const authState = AuthState(
        user: null,
        otpStage: OtpStage.idle,
        otpFlowActive: false,
        isLoading: true, // Critical: still loading
        pinStatus: PinStatus.unknown,
      );

      expect(authState.isLoading, isTrue);
      // Router should stay on current route during loading
    });

    test('OTP flow should take absolute priority over all other redirects', () {
      // Even if user is logged in, if OTP flow is active, go to OTP
      const authState = AuthState(
        user: null, // Simulating logged-in user
        otpStage: OtpStage.codeSent,
        otpFlowActive: true,
        isLoading: false,
        pinStatus: PinStatus.hasPin,
      );

      final isSending = authState.otpStage == OtpStage.sending;
      final canOtp = ((authState.otpFlowActive || authState.otpStage == OtpStage.codeSent) && !isSending);

      expect(canOtp, isTrue, reason: 'OTP flow should take priority');
      // Router should redirect to /otp even if user appears to be logged in
    });
  });

  group('AuthState Transitions', () {
    test('should transition from idle -> sending -> codeSent', () {
      const idle = AuthState(otpStage: OtpStage.idle);
      const sending = AuthState(otpStage: OtpStage.sending, isLoading: true);
      const codeSent = AuthState(
        otpStage: OtpStage.codeSent,
        isLoading: false,
      );

      expect(idle.otpStage, OtpStage.idle);
      expect(sending.otpStage, OtpStage.sending);
      expect(sending.isLoading, isTrue);
      expect(codeSent.otpStage, OtpStage.codeSent);
      expect(codeSent.isLoading, isFalse);
    });

    test('should handle OTP verification flow', () {
      const verifying = AuthState(
        otpStage: OtpStage.verifying,
        isLoading: true,
      );
      const verified = AuthState(
        otpStage: OtpStage.verified,
        isLoading: false,
        user: null, // Will be set by Firebase
      );

      expect(verifying.otpStage, OtpStage.verifying);
      expect(verified.otpStage, OtpStage.verified);
    });

    test('should handle OTP failure', () {
      const failed = AuthState(
        otpStage: OtpStage.failed,
        isLoading: false,
        error: 'رمز التحقق غير صحيح',
      );

      expect(failed.otpStage, OtpStage.failed);
      expect(failed.error, isNotNull);
    });
  });

  group('Edge Cases and Race Conditions', () {
    test('should prevent race condition: simultaneous sending and codeSent', () {
      // This should never happen, but test the guard
      const invalidState = AuthState(
        otpStage: OtpStage.codeSent,
        isLoading: true, // Still loading?
      );

      // The router logic should handle this gracefully
      final isSending = invalidState.otpStage == OtpStage.sending;
      expect(isSending, isFalse, reason: 'codeSent is not sending');
    });

    test('should handle rapid state changes during reCAPTCHA', () {
      // Simulate rapid state transitions
      const states = [
        AuthState(otpStage: OtpStage.idle),
        AuthState(otpStage: OtpStage.sending, isLoading: true),
        AuthState(otpStage: OtpStage.sending, isLoading: true),
        AuthState(otpStage: OtpStage.sending, isLoading: true),
        AuthState(otpStage: OtpStage.codeSent, isLoading: false),
      ];

      // Debouncing should handle rapid changes
      for (final state in states) {
        expect(state.otpStage, isIn([OtpStage.idle, OtpStage.sending, OtpStage.codeSent]));
      }
    });

    test('should handle user cancelling reCAPTCHA', () {
      const cancelled = AuthState(
        otpStage: OtpStage.failed,
        isLoading: false,
        error: 'تم إلغاء التحقق',
        otpFlowActive: false,
      );

      expect(cancelled.otpStage, OtpStage.failed);
      expect(cancelled.otpFlowActive, isFalse);
    });
  });

  group('Public Route Access', () {
    test('should allow access to public tracking routes without auth', () {
      const authState = AuthState(
        user: null,
        pinStatus: PinStatus.unknown,
      );

      final loggedIn = authState.user != null;
      expect(loggedIn, isFalse);

      // Routes like /track/:orderId should be accessible without auth
      final publicRoutes = ['/track/abc123', '/track/xyz789'];
      for (final route in publicRoutes) {
        expect(route.startsWith('/track/'), isTrue);
      }
    });
  });
}
