import 'package:firebase_auth/firebase_auth.dart';

enum OtpStage { idle, sending, codeSent, verifying, verified, failed }

enum PinStatus {
  unknown,
  loading,
  hasPin,
  noPin,
  error,
}

class AuthState {
  final bool isLoading;
  final User? user;
  final String? phoneE164;
  final bool hasPin;
  final String? error;
  final bool otpFlowActive;
  final OtpStage otpStage;
  final bool isPinResetFlow;
  final bool isPinCheckLoading;
  final bool isStreamsSafeToRun;
  final PinStatus pinStatus;

  /// True when the last OTP error was unknown/code-39 and the UI should offer
  /// the user a chance to send a bug report. Set by the notifier, cleared on
  /// the next sendOtp() call. This avoids string-matching Arabic error text.
  final bool shouldOfferBugReport;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.phoneE164,
    this.hasPin = false,
    this.error,
    this.otpFlowActive = false,
    this.otpStage = OtpStage.idle,
    this.isPinResetFlow = false,
    this.isPinCheckLoading = false,
    this.isStreamsSafeToRun = true,
    this.pinStatus = PinStatus.unknown,
    this.shouldOfferBugReport = false,
  });

  AuthState copyWith({
    bool? isLoading,
    User? user,
    String? phoneE164,
    bool? hasPin,
    String? error,
    bool? otpFlowActive,
    OtpStage? otpStage,
    bool? isPinResetFlow,
    bool? isPinCheckLoading,
    bool? isStreamsSafeToRun,
    PinStatus? pinStatus,
    bool? shouldOfferBugReport,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      phoneE164: phoneE164 ?? this.phoneE164,
      hasPin: hasPin ?? this.hasPin,
      error: error, // Error is typically nullable/resettable
      otpFlowActive: otpFlowActive ?? this.otpFlowActive,
      otpStage: otpStage ?? this.otpStage,
      isPinResetFlow: isPinResetFlow ?? this.isPinResetFlow,
      isPinCheckLoading: isPinCheckLoading ?? this.isPinCheckLoading,
      isStreamsSafeToRun: isStreamsSafeToRun ?? this.isStreamsSafeToRun,
      pinStatus: pinStatus ?? this.pinStatus,
      shouldOfferBugReport: shouldOfferBugReport ?? this.shouldOfferBugReport,
    );
  }
}
