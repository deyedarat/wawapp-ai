import '../entities/driver_entity.dart';

abstract class AuthRepository {
  Stream<DriverEntity?> get authStateChanges;
  DriverEntity? get currentDriver;
  
  Future<String> sendOTP(String phoneNumber);
  Future<DriverEntity> verifyOTP({
    required String verificationId,
    required String otp,
    required String pin,
  });
  Future<DriverEntity> loginWithPin({
    required String phoneNumber,
    required String pin,
  });
  Future<void> resetPin({
    required String phoneNumber,
    required String verificationId,
    required String otp,
    required String newPin,
  });
  Future<void> signOut();
}