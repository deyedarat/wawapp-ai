// Placeholder for phone_pin_auth service
// This file is referenced by test files but not used in production
abstract class PhonePinAuth {
  Future<void> ensurePhoneSession(String phoneE164,
      {void Function()? onCodeSent});
  Future<void> confirmOtp(String smsCode);
  Future<void> setPin(String pin);
  Future<bool> verifyPin(String pin);
  Future<bool> hasPinHash();
  Future<void> signOut();
}
