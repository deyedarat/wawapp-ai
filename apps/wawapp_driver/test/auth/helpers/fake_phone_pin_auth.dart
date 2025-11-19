import 'dart:async';
import 'package:wawapp_driver/services/phone_pin_auth.dart';

/// Fake PhonePinAuth service for testing
/// Does not hit network or Firebase
class FakePhonePinAuth implements PhonePinAuth {
  FakePhonePinAuth({
    this.shouldFailSendOtp = false,
    this.shouldFailVerifyOtp = false,
    this.shouldFailSetPin = false,
    this.shouldFailVerifyPin = false,
    this.initialHasPin = false,
    this.pinIsValid = true,
  });

  bool shouldFailSendOtp;
  bool shouldFailVerifyOtp;
  bool shouldFailSetPin;
  bool shouldFailVerifyPin;
  bool initialHasPin;
  bool pinIsValid;

  String? _storedPin;
  String? _lastPhone;
  bool _otpSent = false;

  // Track method calls for verification
  int sendOtpCallCount = 0;
  int verifyOtpCallCount = 0;
  int setPinCallCount = 0;
  int verifyPinCallCount = 0;
  int hasPinHashCallCount = 0;
  int signOutCallCount = 0;

  String? get lastPhone => _lastPhone;
  bool get otpSent => _otpSent;
  String? get storedPin => _storedPin;

  void reset() {
    _storedPin = null;
    _lastPhone = null;
    _otpSent = false;
    sendOtpCallCount = 0;
    verifyOtpCallCount = 0;
    setPinCallCount = 0;
    verifyPinCallCount = 0;
    hasPinHashCallCount = 0;
    signOutCallCount = 0;
    shouldFailSendOtp = false;
    shouldFailVerifyOtp = false;
    shouldFailSetPin = false;
    shouldFailVerifyPin = false;
    initialHasPin = false;
    pinIsValid = true;
  }

  @override
  Future<void> ensurePhoneSession(String phoneE164,
      {void Function()? onCodeSent}) async {
    sendOtpCallCount++;
    _lastPhone = phoneE164;

    if (shouldFailSendOtp) {
      throw Exception('Failed to send OTP');
    }

    // Validate E.164 format
    final e164Pattern = RegExp(r'^\+[1-9]\d{6,14}$');
    if (!e164Pattern.hasMatch(phoneE164)) {
      throw Exception('Invalid phone number format');
    }

    _otpSent = true;
    onCodeSent?.call();
  }

  @override
  Future<void> confirmOtp(String smsCode) async {
    verifyOtpCallCount++;

    if (shouldFailVerifyOtp) {
      throw Exception('Invalid OTP code');
    }

    if (!_otpSent) {
      throw Exception('No OTP session');
    }

    // Simulate successful verification
  }

  @override
  Future<void> setPin(String pin) async {
    setPinCallCount++;

    if (shouldFailSetPin) {
      throw Exception('Failed to set PIN');
    }

    _storedPin = pin;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    verifyPinCallCount++;

    if (shouldFailVerifyPin) {
      throw Exception('Failed to verify PIN');
    }

    if (_storedPin == null) {
      return false;
    }

    if (!pinIsValid) {
      return false;
    }

    return pin == _storedPin;
  }

  @override
  Future<bool> hasPinHash() async {
    hasPinHashCallCount++;

    if (_storedPin != null) {
      return true;
    }

    return initialHasPin;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    _storedPin = null;
    _lastPhone = null;
    _otpSent = false;
  }

  @override
  String? get lastVerificationId => throw UnimplementedError();
}
