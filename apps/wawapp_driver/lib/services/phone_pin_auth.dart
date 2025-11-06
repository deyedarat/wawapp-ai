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
  PhonePinAuth._();
  static final instance = PhonePinAuth._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<DocumentReference<Map<String, dynamic>>> _userDoc() async {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid);
  }

  Future<void> ensurePhoneSession(String phoneE164) async {
    final u = _auth.currentUser;
    if (u != null) {
      if (kDebugMode) {
        print('[PhonePinAuth] ensurePhoneSession: already signed in');
      }
      return;
    }

    if (kDebugMode) {
      print('[PhonePinAuth] ensurePhoneSession: starting verification');
    }

    final completer = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        if (kDebugMode) {
          print('[PhonePinAuth] verificationCompleted: auto sign-in');
        }
        await _auth.signInWithCredential(cred);
        completer.complete();
      },
      verificationFailed: (FirebaseAuthException e) {
        if (kDebugMode) {
          print(
              '[PhonePinAuth] verificationFailed: code=${e.code}, message=${e.message}');
        }
        completer.completeError(e);
      },
      codeSent: (verificationId, _) {
        if (kDebugMode) {
          print('[PhonePinAuth] codeSent');
        }
        _lastVerificationId = verificationId;
        completer.complete();
      },
      codeAutoRetrievalTimeout: (vid) => _lastVerificationId = vid,
    );
    await completer.future;
  }

  String? _lastVerificationId;
  String? get lastVerificationId => _lastVerificationId;

  Future<void> confirmOtp(String smsCode) async {
    final vid = _lastVerificationId;
    if (vid == null) {
      if (kDebugMode) {
        print('[PhonePinAuth] confirmOtp: no verification id');
      }
      throw Exception('No verification id');
    }
    if (kDebugMode) {
      print('[PhonePinAuth] confirmOtp: verifying code');
    }
    final cred =
        PhoneAuthProvider.credential(verificationId: vid, smsCode: smsCode);
    await _auth.signInWithCredential(cred);
    if (kDebugMode) {
      print('[PhonePinAuth] confirmOtp: success');
    }
  }

  Future<void> setPin(String pin) async {
    final doc = await _userDoc();
    final salt = _generateSalt();
    final hash = _hashWithSalt(pin, salt);

    if (kDebugMode) {
      print('[PhonePinAuth] setPin: storing salted pin hash');
    }

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
    if (data == null) {
      return false;
    }

    final storedHash = data['pinHash'] as String?;
    final storedSalt = data['pinSalt'] as String?;
    if (storedHash == null) {
      return false;
    }

    if (storedSalt != null) {
      final computed = _hashWithSalt(pin, storedSalt);
      return computed == storedHash;
    } else {
      // Legacy: uid + pin -> sha256
      final oldCombined = '$uid:$pin';
      final oldHash = sha256.convert(utf8.encode(oldCombined)).toString();
      final ok = (oldHash == storedHash);
      if (ok) {
        // Immediate migration to salted
        final newSalt = _generateSalt();
        final newHash = _hashWithSalt(pin, newSalt);
        await docRef.set(
            {'pinSalt': newSalt, 'pinHash': newHash}, SetOptions(merge: true));
        if (kDebugMode) {
          print('[PhonePinAuth] verifyPin: migrated to salted hash');
        }
      }
      return ok;
    }
  }

  Future<bool> hasPinHash() async {
    final doc = await _userDoc();
    final snap = await doc.get();
    final data = snap.data();
    final exists = data?['pinHash'] != null;
    if (kDebugMode) {
      print('[PhonePinAuth] hasPinHash: $exists');
    }
    return exists;
  }

  Future<void> signOut() => _auth.signOut();
}
