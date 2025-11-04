import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../services/phone_auth_service.dart';
import '../../services/pin_service.dart';
import '../models/user_model.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final PhoneAuthService _phoneService;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    PhoneAuthService? phoneService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _phoneService = phoneService ?? PhoneAuthService();

  @override
  Future<void> sendOTP(String phoneNumber) async {
    if (!PhoneAuthService.isValidPhoneNumber(phoneNumber)) {
      throw Exception('Invalid phone number format');
    }
  }

  @override
  Future<UserEntity> verifyOTPAndCreateAccount({
    required String verificationId,
    required String otp,
    required String pin,
    required AccountType accountType,
  }) async {
    if (!PinService.isValidPin(pin)) {
      throw Exception('Invalid PIN format');
    }

    final userCredential = await _phoneService.verifyOTP(
      verificationId: verificationId,
      otpCode: otp,
    );

    final user = userCredential.user;
    if (user == null) throw Exception('Authentication failed');

    final salt = PinService.generateSalt();
    final pinHash = await PinService.hashPin(pin, salt);

    final userModel = UserModel(
      uid: user.uid,
      phoneNumber: user.phoneNumber!,
      accountType: accountType,
      createdAt: DateTime.now(),
      isActive: true,
      lockoutInfo: const LockoutInfoModel(
        failedAttempts: 0,
        lockoutLevel: 0,
      ),
    );

    await _firestore.collection('users').doc(user.uid).set({
      ...userModel.toFirestore(),
      'pinHash': pinHash,
      'pinSalt': salt,
    });

    return userModel;
  }

  @override
  Future<UserEntity> loginWithPhoneAndPin({
    required String phoneNumber,
    required String pin,
  }) async {
    final usersQuery = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (usersQuery.docs.isEmpty) {
      throw Exception('User not found');
    }

    final userDoc = usersQuery.docs.first;
    final userData = userDoc.data();
    final userModel = UserModel.fromFirestore(userDoc);

    if (userModel.lockoutInfo.isLocked) {
      final duration = userModel.lockoutInfo.lockedUntil!.difference(DateTime.now());
      throw Exception('Account locked. Try again in ${duration.inMinutes} minutes');
    }

    final pinHash = userData['pinHash'] as String;
    final pinSalt = userData['pinSalt'] as String;

    final isValid = await PinService.verifyPin(pin, pinHash, pinSalt);

    if (!isValid) {
      throw Exception('Invalid PIN');
    }

    await _firestore.collection('users').doc(userDoc.id).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lockoutInfo.failedAttempts': 0,
    });

    return userModel;
  }

  @override
  Future<void> resetPin({
    required String phoneNumber,
    required String verificationId,
    required String otp,
    required String newPin,
  }) async {
    if (!PinService.isValidPin(newPin)) {
      throw Exception('Invalid PIN format');
    }

    await _phoneService.verifyOTP(
      verificationId: verificationId,
      otpCode: otp,
    );

    final usersQuery = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (usersQuery.docs.isEmpty) {
      throw Exception('User not found');
    }

    final userDoc = usersQuery.docs.first;
    final salt = PinService.generateSalt();
    final pinHash = await PinService.hashPin(newPin, salt);

    await _firestore.collection('users').doc(userDoc.id).update({
      'pinHash': pinHash,
      'pinSalt': salt,
      'lockoutInfo': const LockoutInfoModel(
        failedAttempts: 0,
        lockoutLevel: 0,
      ).toMap(),
    });
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromFirestore(doc);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
