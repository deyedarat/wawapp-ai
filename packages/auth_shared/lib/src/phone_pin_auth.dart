import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

String _generateSalt() {
  final r = Random.secure();
  final saltBytes = List<int>.generate(16, (_) => r.nextInt(256));
  return base64UrlEncode(saltBytes);
}

String _hashWithSalt(String pin, String salt) {
  final combined = '$pin:$salt';
  return sha256.convert(utf8.encode(combined)).toString();
}

class PhonePinAuth {
  PhonePinAuth._(this.userCollection);
  static PhonePinAuth? _instance;

  factory PhonePinAuth({required String userCollection}) {
    _instance ??= PhonePinAuth._(userCollection);
    return _instance!;
  }

  final String userCollection;
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<DocumentReference<Map<String, dynamic>>> _userDoc() async {
    final uid = _auth.currentUser!.uid;
    return _db.collection(userCollection).doc(uid);
  }

  String? _lastVerificationId;
  String? get lastVerificationId => _lastVerificationId;

  Future<void> ensurePhoneSession(String phoneE164) async {
    final u = _auth.currentUser;
    if (u != null) {
      if (kDebugMode) print('[PhonePinAuth] already signed in');
      return;
    }

    final completer = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        if (kDebugMode) print('[PhonePinAuth] auto sign-in');
        await _auth.signInWithCredential(cred);
        completer.complete();
      },
      verificationFailed: (e) {
        if (kDebugMode) print('[PhonePinAuth] failed: ${e.message}');
        completer.completeError(e);
      },
      codeSent: (verificationId, _) {
        if (kDebugMode) print('[PhonePinAuth] codeSent');
        _lastVerificationId = verificationId;
        completer.complete();
      },
      codeAutoRetrievalTimeout: (vid) => _lastVerificationId = vid,
    );
    await completer.future;
  }

  Future<void> confirmOtp(String smsCode) async {
    final vid = _lastVerificationId;
    if (vid == null) throw Exception('No verification id');
    final cred = PhoneAuthProvider.credential(
      verificationId: vid,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(cred);
  }

  Future<void> setPin(String pin) async {
    final doc = await _userDoc();
    final salt = _generateSalt();
    final hash = _hashWithSalt(pin, salt);
    await doc.set({
      'phone': _auth.currentUser!.phoneNumber,
      'pinSalt': salt,
      'pinHash': hash,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> verifyPin(String pin) async {
    final uid = _auth.currentUser!.uid;
    final docRef = await _userDoc();
    final snap = await docRef.get();
    final data = snap.data();
    if (data == null) return false;

    final storedHash = data['pinHash'] as String?;
    final storedSalt = data['pinSalt'] as String?;
    if (storedHash == null) return false;

    if (storedSalt != null) {
      return _hashWithSalt(pin, storedSalt) == storedHash;
    } else {
      final oldHash = sha256.convert(utf8.encode('$uid:$pin')).toString();
      final ok = oldHash == storedHash;
      if (ok) {
        final newSalt = _generateSalt();
        await docRef.set({
          'pinSalt': newSalt,
          'pinHash': _hashWithSalt(pin, newSalt),
        }, SetOptions(merge: true));
      }
      return ok;
    }
  }

  Future<bool> hasPinHash() async {
    final doc = await _userDoc();
    final snap = await doc.get();
    return snap.data()?['pinHash'] != null;
  }

  Future<bool> phoneExists(String phoneE164) async {
    final snap = await _db
        .collection(userCollection)
        .where('phone', isEqualTo: phoneE164)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> signOut() => _auth.signOut();
}
