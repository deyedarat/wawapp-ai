import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../domain/entities/driver_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/driver_model.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<DriverEntity?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      final doc = await _firestore.collection('drivers').doc(user.uid).get();
      return doc.exists ? DriverModel.fromFirestore(doc) : null;
    });
  }

  @override
  DriverEntity? get currentDriver {
    final user = _auth.currentUser;
    return user != null ? DriverEntity(id: user.uid, phoneNumber: user.phoneNumber ?? '') : null;
  }

  @override
  Future<String> sendOTP(String phoneNumber) async {
    final completer = Completer<String>();
    
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (e) => completer.completeError(e),
      codeSent: (verificationId, _) => completer.complete(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
    
    return completer.future;
  }

  @override
  Future<DriverEntity> verifyOTP({
    required String verificationId,
    required String otp,
    required String pin,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    
    final result = await _auth.signInWithCredential(credential);
    final user = result.user!;
    
    final hashedPin = sha256.convert(utf8.encode(pin)).toString();
    
    final driver = DriverModel(
      id: user.uid,
      phoneNumber: user.phoneNumber!,
      status: DriverStatus.offline,
    );
    
    await _firestore.collection('drivers').doc(user.uid).set({
      ...driver.toFirestore(),
      'hashedPin': hashedPin,
    });
    
    return driver;
  }

  @override
  Future<DriverEntity> loginWithPin({
    required String phoneNumber,
    required String pin,
  }) async {
    final hashedPin = sha256.convert(utf8.encode(pin)).toString();
    
    final query = await _firestore
        .collection('drivers')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .where('hashedPin', isEqualTo: hashedPin)
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) {
      throw Exception('Invalid phone number or PIN');
    }
    
    final driverDoc = query.docs.first;
    final driver = DriverModel.fromFirestore(driverDoc);
    
    await _auth.signInAnonymously();
    
    return driver;
  }

  @override
  Future<void> resetPin({
    required String phoneNumber,
    required String verificationId,
    required String otp,
    required String newPin,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    
    await _auth.signInWithCredential(credential);
    final user = _auth.currentUser!;
    
    final hashedPin = sha256.convert(utf8.encode(newPin)).toString();
    
    await _firestore.collection('drivers').doc(user.uid).update({
      'hashedPin': hashedPin,
    });
  }

  @override
  Future<void> signOut() => _auth.signOut();
}