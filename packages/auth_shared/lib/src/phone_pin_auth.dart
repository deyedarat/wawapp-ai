import 'dart:async';
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

  bool _authInitialized = false;

  // Force reCAPTCHA flow for all builds (required for iOS reCAPTCHA callback via URL Scheme)
  Future<void> _initializeAuth() async {
    if (_authInitialized) return;
    await _auth.setSettings(
      appVerificationDisabledForTesting: false,
    );
    _authInitialized = true;
    if (kDebugMode) {
      print('[PhonePinAuth] Auth initialized (reCAPTCHA as fallback only)');
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _userDoc() async {
    final uid = _auth.currentUser!.uid;
    return _db.collection(userCollection).doc(uid);
  }

  String? _lastVerificationId;
  String? get lastVerificationId => _lastVerificationId;

  /// Last phone number (E.164) for which a session was requested.
  /// Used by the bug report screen to retrieve the masked phone.
  String? _lastPhoneE164;
  String? get lastPhoneE164 => _lastPhoneE164;

  // Track in-flight phone session request to prevent concurrent calls
  Future<void>? _inFlightPhoneSession;

  Future<void> ensurePhoneSession(
    String phoneE164, {
    bool forceNewSession = false,

    /// Optional structured log callback. Receives (event, maskedPhone, errorCode, errorMessage).
    /// Avoids a reverse dependency: auth_shared → client services.
    void Function(String event, String? phone, String? code, String? msg)? onLog,
  }) async {
    // Track last phone for bug-report screen
    _lastPhoneE164 = phoneE164;

    // If a session request is already in-flight and we're not forcing a new one, return the existing future
    if (_inFlightPhoneSession != null && !forceNewSession) {
      if (kDebugMode) {
        print('[PhonePinAuth] ensurePhoneSession() already in progress, returning existing future');
      }
      return _inFlightPhoneSession!;
    }

    // Initialize auth settings (force reCAPTCHA on iOS)
    await _initializeAuth();

    final maskedPhone =
        phoneE164.length > 5 ? '${phoneE164.substring(0, 4)}******${phoneE164.substring(phoneE164.length - 3)}' : '***';

    if (kDebugMode) {
      print('[PhonePinAuth] ensurePhoneSession() starting for phone=$maskedPhone, forceNewSession=$forceNewSession');
    }
    // Always-on Crashlytics breadcrumb
    FirebaseCrashlytics.instance.log('OTP_SEND_START: phone=$maskedPhone');
    onLog?.call('otp_send_start', phoneE164, null, null);

    final u = _auth.currentUser;
    if (u != null && !forceNewSession) {
      if (kDebugMode) print('[PhonePinAuth] already signed in, uid=${u.uid}');
      return;
    }

    if (u != null && forceNewSession) {
      if (kDebugMode) print('[PhonePinAuth] Signing out to force new OTP session');
      await _auth.signOut();
    }

    final completer = Completer<void>();

    if (kDebugMode) {
      print(
          '[PhonePinAuth] DIAGNOSTIC: Calling Firebase verifyPhoneNumber() for phone=$phoneE164 at ${DateTime.now()}');
      FirebaseCrashlytics.instance.log('OTP_VERIFY_PHONE_START: ${DateTime.now()}');
    }

    try {
      _inFlightPhoneSession = completer.future;

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          if (kDebugMode) print('[PhonePinAuth] verificationCompleted - auto sign-in');
          FirebaseCrashlytics.instance.log('OTP_VERIFICATION_COMPLETED');
          onLog?.call('verification_completed', phoneE164, null, null);
          try {
            await _auth.signInWithCredential(cred);
            if (kDebugMode) print('[PhonePinAuth] Auto sign-in successful');
            if (!completer.isCompleted) completer.complete();
          } on Object catch (e) {
            if (kDebugMode) print('[PhonePinAuth] Auto sign-in failed: $e');
            FirebaseCrashlytics.instance.log('OTP_AUTO_SIGNIN_FAILED');
            onLog?.call('auto_signin_failed', phoneE164, null, e.runtimeType.toString());
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
        verificationFailed: (e) {
          if (kDebugMode) print('[PhonePinAuth] verificationFailed - code: ${e.code}');
          // Always-on: record as non-fatal in Crashlytics (not behind kDebugMode)
          // Use the exception's own stackTrace when available (Firebase provides it),
          // fall back to StackTrace.current so the event is always trackable.
          FirebaseCrashlytics.instance.recordError(
            'OTP Verification Failed',
            e.stackTrace ?? StackTrace.current,
            fatal: false,
            reason: 'code=${e.code}',
            printDetails: false,
            information: ['phone=$maskedPhone', 'code=${e.code}'],
          );
          onLog?.call('verification_failed', phoneE164, e.code, e.message);
          if (!completer.isCompleted) completer.completeError(e);
        },
        codeSent: (verificationId, resendToken) {
          if (kDebugMode) print('[PhonePinAuth] codeSent - verificationId=present (not logged)');
          // Never log verificationId — it's a sensitive session credential
          FirebaseCrashlytics.instance.log('OTP_CODE_SENT');
          onLog?.call('otp_sent', phoneE164, null, null);
          _lastVerificationId = verificationId;
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (vid) {
          if (kDebugMode) print('[PhonePinAuth] codeAutoRetrievalTimeout');
          // Never log verificationId
          FirebaseCrashlytics.instance.log('OTP_AUTO_RETRIEVAL_TIMEOUT');
          onLog?.call('otp_auto_retrieval_timeout', phoneE164, null, null);
          _lastVerificationId = vid;
        },
      );

      await completer.future;

      if (kDebugMode) print('[PhonePinAuth] ensurePhoneSession() completed successfully');
      FirebaseCrashlytics.instance.log('OTP_SEND_SUCCESS');
      onLog?.call('otp_send_success', phoneE164, null, null);
    } catch (e, stackTrace) {
      if (kDebugMode) print('[PhonePinAuth] ensurePhoneSession() EXCEPTION: ${e.runtimeType}');
      // Always-on non-fatal recording (no sensitive data in message)
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        fatal: false,
        reason: 'ensurePhoneSession failed',
        printDetails: false,
      );
      rethrow;
    } finally {
      _inFlightPhoneSession = null;
    }
  }

  Future<void> confirmOtp(String smsCode) async {
    if (kDebugMode) print('[PhonePinAuth] confirmOtp() called');

    final vid = _lastVerificationId;
    if (vid == null) {
      if (kDebugMode) print('[PhonePinAuth] ERROR: No verification ID available');
      throw Exception('No verification id');
    }

    try {
      final cred = PhoneAuthProvider.credential(verificationId: vid, smsCode: smsCode);
      await _auth.signInWithCredential(cred);
      if (kDebugMode) print('[PhonePinAuth] Sign-in successful!');
    } catch (e) {
      if (kDebugMode) print('[PhonePinAuth] Sign-in FAILED: ${e.runtimeType} - $e');
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
