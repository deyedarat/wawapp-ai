import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhonePinAuth {
  PhonePinAuth._();
  static final instance = PhonePinAuth._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Map<String, String> _hashPin(String pin) {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final saltB64 = base64UrlEncode(salt);
    final h = sha256.convert(utf8.encode('$pin:$saltB64')).toString();
    return {'salt': saltB64, 'hash': h};
  }

  String _hashWith(String pin, String saltB64) {
    return sha256.convert(utf8.encode('$pin:$saltB64')).toString();
  }

  Future<DocumentReference<Map<String, dynamic>>> _userDoc() async {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid);
  }

  Future<void> ensurePhoneSession(String phoneE164) async {
    final u = _auth.currentUser;
    if (u != null) return;

    final completer = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        await _auth.signInWithCredential(cred);
        completer.complete();
      },
      verificationFailed: (e) => completer.completeError(e),
      codeSent: (verificationId, _) {
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
      throw Exception('No verification id');
    }
    final cred =
        PhoneAuthProvider.credential(verificationId: vid, smsCode: smsCode);
    await _auth.signInWithCredential(cred);
  }

  Future<void> setPin(String pin) async {
    final doc = await _userDoc();
    final hp = _hashPin(pin);
    await doc.set({
      'phone': _auth.currentUser!.phoneNumber,
      'pinSalt': hp['salt'],
      'pinHash': hp['hash'],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> verifyPin(String pin) async {
    final doc = await _userDoc();
    final snap = await doc.get();
    final data = snap.data();
    if (data == null) return false;
    final salt = data['pinSalt'] as String?;
    final hash = data['pinHash'] as String?;
    if (salt == null || hash == null) return false;
    final h = _hashWith(pin, salt);
    return h == hash;
  }

  Future<void> signOut() => _auth.signOut();
}
