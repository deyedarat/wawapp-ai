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
  final String? verificationId;
  final int? resendToken;
  final bool isPinResetFlow;
  final bool isPinCheckLoading;
  final bool isStreamsSafeToRun;
  final PinStatus pinStatus; // New field

  const AuthState({
    this.isLoading = false,
    this.user,
    this.phoneE164,
    this.hasPin = false,
    this.error,
    this.otpFlowActive = false,
    this.otpStage = OtpStage.idle,
    this.verificationId,
    this.resendToken,
    this.isPinResetFlow = false,
    this.isPinCheckLoading = false,
    this.isStreamsSafeToRun = true,
    this.pinStatus = PinStatus.unknown, // Default
  });

  AuthState copyWith({
    bool? isLoading,
    User? user,
    String? phoneE164,
    bool? hasPin,
    String? error,
    bool? otpFlowActive,
    OtpStage? otpStage,
    String? verificationId,
    int? resendToken,
    bool? isPinResetFlow,
    bool? isPinCheckLoading,
    bool? isStreamsSafeToRun,
    PinStatus? pinStatus,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      phoneE164: phoneE164 ?? this.phoneE164,
      hasPin: hasPin ?? this.hasPin,
      error: error, // Error is typically nullable/resettable
      otpFlowActive: otpFlowActive ?? this.otpFlowActive,
      otpStage: otpStage ?? this.otpStage,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      isPinResetFlow: isPinResetFlow ?? this.isPinResetFlow,
      isPinCheckLoading: isPinCheckLoading ?? this.isPinCheckLoading,
      isStreamsSafeToRun: isStreamsSafeToRun ?? this.isStreamsSafeToRun,
      pinStatus: pinStatus ?? this.pinStatus,
    );
  }
}
