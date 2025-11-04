import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<void> sendOTP(String phoneNumber);
  
  Future<UserEntity> verifyOTPAndCreateAccount({
    required String verificationId,
    required String otp,
    required String pin,
    required AccountType accountType,
  });
  
  Future<UserEntity> loginWithPhoneAndPin({
    required String phoneNumber,
    required String pin,
  });
  
  Future<void> resetPin({
    required String phoneNumber,
    required String verificationId,
    required String otp,
    required String newPin,
  });
  
  Future<UserEntity?> getCurrentUser();
  Future<void> signOut();
}