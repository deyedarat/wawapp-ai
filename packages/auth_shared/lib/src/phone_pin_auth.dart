import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

  /// Last phone number (E.164) for which a session was requested.
  /// Used by the bug report screen to retrieve the masked phone.
  String? _lastPhoneE164;
  String? get lastPhoneE164 => _lastPhoneE164;

  Future<DocumentReference<Map<String, dynamic>>> _userDoc() async {
    final uid = _auth.currentUser!.uid;
    return _db.collection(userCollection).doc(uid);
  }

  Future<void> ensurePhoneSession(
    String phoneE164, {
    bool forceNewSession = false,

    /// Optional structured log callback. Receives (event, maskedPhone, errorCode, errorMessage).
    /// Avoids a reverse dependency: auth_shared → client services.
    void Function(String event, String? phone, String? code, String? msg)? onLog,
  }) async {
    // Track last phone for bug-report screen
    _lastPhoneE164 = phoneE164;

    final maskedPhone =
        phoneE164.length > 5 ? '${phoneE164.substring(0, 4)}******${phoneE164.substring(phoneE164.length - 3)}' : '***';

    if (kDebugMode) {
      print('[PhonePinAuth] ensurePhoneSession() starting for phone=$maskedPhone');
    }
    // Always-on Crashlytics breadcrumb
    FirebaseCrashlytics.instance.log('OTP_SEND_START: phone=$maskedPhone');
    onLog?.call('otp_send_start', phoneE164, null, null);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendOtp');
      await callable.call({'phone': phoneE164});

      if (kDebugMode) print('[PhonePinAuth] ensurePhoneSession() completed successfully');
      FirebaseCrashlytics.instance.log('OTP_SEND_SUCCESS');
      onLog?.call('otp_send_success', phoneE164, null, null);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) print('[PhonePinAuth] ensurePhoneSession() FAILED: ${e.code} - ${e.message}');
      FirebaseCrashlytics.instance.recordError(
        'OTP Send Failed',
        StackTrace.current,
        fatal: false,
        reason: 'code=${e.code}',
        printDetails: false,
        information: ['phone=$maskedPhone', 'code=${e.code}'],
      );
      onLog?.call('otp_send_failed', phoneE164, e.code, e.message);
      rethrow;
    }
  }

  Future<bool> confirmOtp(String smsCode) async {
    if (kDebugMode) print('[PhonePinAuth] confirmOtp() called');

    if (_lastPhoneE164 == null) throw Exception('No phone number available');

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyOtp');
      final userType = userCollection == 'drivers' ? 'driver' : 'user';
      final result = await callable.call({
        'phone': _lastPhoneE164,
        'code': smsCode,
        'userType': userType,
      });

      final customToken = result.data['customToken'] as String?;
      final isNewUser = result.data['isNewUser'] as bool? ?? false;

      if (customToken == null) throw Exception('No custom token returned');

      if (kDebugMode) print('[PhonePinAuth] OTP verified, signing in with custom token');
      await _auth.signInWithCustomToken(customToken);
      if (kDebugMode) print('[PhonePinAuth] Sign-in successful!');

      return isNewUser;
    } on FirebaseFunctionsException {
      rethrow;
    }
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

  Future<bool> verifyPin(String pin, String phoneE164) async {
    if (kDebugMode) {
      final maskedPhone =
          phoneE164.length > 5 ? '${phoneE164.substring(0, 3)}...${phoneE164.substring(phoneE164.length - 2)}' : '***';
      print('[PhonePinAuth] Verifying PIN for phone: $maskedPhone');
    }

    if (!phoneE164.startsWith('+')) {
      throw ArgumentError('Phone must be in E.164 format (starting with +)');
    }

    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.phoneNumber == phoneE164) {
      if (kDebugMode) print('[PhonePinAuth] User already signed in with matching phone');
      return true;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createCustomToken');
      final userType = userCollection == 'drivers' ? 'driver' : 'user';
      final result = await callable.call({
        'phoneE164': phoneE164,
        'pin': pin,
        'userType': userType,
      });

      final token = result.data['token'] as String?;
      final uid = result.data['uid'] as String?;

      if (token == null) {
        if (kDebugMode) print('[PhonePinAuth] No token returned from createCustomToken');
        return false;
      }

      if (kDebugMode) print('[PhonePinAuth] Custom token received, signing in user: $uid');
      await _auth.signInWithCustomToken(token);
      if (kDebugMode) print('[PhonePinAuth] Successfully signed in with custom token');
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) print('[PhonePinAuth] Cloud Function error: ${e.code} - ${e.message}');
      return false;
    } on Object catch (e) {
      if (kDebugMode) print('[PhonePinAuth] Error verifying PIN: $e');
      return false;
    }
  }

  Future<bool> hasPinHash() async {
    final doc = await _userDoc();
    final snap = await doc.get();
    return snap.data()?['pinHash'] != null;
  }

  Future<bool> phoneExists(String phoneE164) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('checkPhoneExists');
      final userType = userCollection == 'drivers' ? 'driver' : 'user';
      final result = await callable.call({
        'phoneE164': phoneE164,
        'userType': userType,
      });
      return result.data['exists'] as bool? ?? false;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) print('[PhonePinAuth] Cloud Function error checking phone: ${e.code} - ${e.message}');
      return false;
    } on Object catch (e) {
      if (kDebugMode) print('[PhonePinAuth] Error checking phone existence: $e');
      return false;
    }
  }

  Future<void> signOut() => _auth.signOut();
}
