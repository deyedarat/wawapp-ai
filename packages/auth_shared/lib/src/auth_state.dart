import 'package:firebase_auth/firebase_auth.dart';

enum OtpStage { idle, sending, codeSent, verifying, verified, failed }

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
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      phoneE164: phoneE164 ?? this.phoneE164,
      hasPin: hasPin ?? this.hasPin,
      error: error,
      otpFlowActive: otpFlowActive ?? this.otpFlowActive,
      otpStage: otpStage ?? this.otpStage,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
    );
  }
}
