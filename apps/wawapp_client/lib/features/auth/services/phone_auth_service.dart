import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  final FirebaseAuth _auth;
  
  PhoneAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static const int otpTimeoutSeconds = 300;
  static const int resendCooldownSeconds = 30;

  static bool isValidPhoneNumber(String phoneNumber) {
    return RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(phoneNumber);
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        timeout: const Duration(seconds: otpTimeoutSeconds),
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String otpCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otpCode,
    );
    return await _auth.signInWithCredential(credential);
  }
}