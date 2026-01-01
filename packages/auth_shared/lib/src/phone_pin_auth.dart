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

  // Enable reCAPTCHA fallback for debug builds
  Future<void> _initializeAuth() async {
    if (kDebugMode) {
      // Force reCAPTCHA flow for debug builds to avoid Play Integrity issues
      await _auth.setSettings(
        appVerificationDisabledForTesting: false,
        forceRecaptchaFlow: true,
      );
      if (kDebugMode) {
        print('[PhonePinAuth] Initialized with forceRecaptchaFlow=true for debug build');
      }
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _userDoc() async {
    final uid = _auth.currentUser!.uid;
    return _db.collection(userCollection).doc(uid);
  }

  String? _lastVerificationId;
  String? get lastVerificationId => _lastVerificationId;

  Future<void> ensurePhoneSession(String phoneE164, {bool forceNewSession = false}) async {
    // Initialize auth settings for debug builds (enable reCAPTCHA)
    await _initializeAuth();

    if (kDebugMode) {
      print(
        '[PhonePinAuth] ensurePhoneSession() starting Firebase Auth flow for phone=$phoneE164, forceNewSession=$forceNewSession',
      );
      // Add Crashlytics breadcrumb for debugging
      FirebaseCrashlytics.instance.log('OTP_SEND_START: phone=$phoneE164, forceNewSession=$forceNewSession');
    }

    final u = _auth.currentUser;
    if (u != null && !forceNewSession) {
      if (kDebugMode) print('[PhonePinAuth] already signed in, uid=${u.uid}');
      return;
    }

    // If forceNewSession, sign out first to get new OTP
    if (u != null && forceNewSession) {
      if (kDebugMode) print('[PhonePinAuth] Signing out to force new OTP session');
      await _auth.signOut();
    }

    final completer = Completer<void>();

    if (kDebugMode) {
      print(
        '[PhonePinAuth] DIAGNOSTIC: Calling Firebase verifyPhoneNumber() for phone=$phoneE164 at ${DateTime.now()}',
      );
      FirebaseCrashlytics.instance.log('OTP_VERIFY_PHONE_START: ${DateTime.now()}');
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          if (kDebugMode) {
            print('[PhonePinAuth] DIAGNOSTIC: verificationCompleted callback - auto sign-in');
            FirebaseCrashlytics.instance.log('OTP_VERIFICATION_COMPLETED');
          }
          try {
            await _auth.signInWithCredential(cred);
            if (kDebugMode) print('[PhonePinAuth] Auto sign-in successful');
            completer.complete();
          } on Object catch (e) {
            if (kDebugMode) {
              print('[PhonePinAuth] DIAGNOSTIC: Auto sign-in failed: $e');
              FirebaseCrashlytics.instance.log('OTP_AUTO_SIGNIN_FAILED: $e');
            }
            completer.completeError(e);
          }
        },
        verificationFailed: (e) {
          if (kDebugMode) {
            print(
              '[PhonePinAuth] DIAGNOSTIC: verificationFailed callback - code: ${e.code}, message: ${e.message}, details: ${e.toString()}',
            );
            FirebaseCrashlytics.instance.log('OTP_VERIFICATION_FAILED: code=${e.code}, message=${e.message}');
            // Record non-fatal error for detailed analysis
            FirebaseCrashlytics.instance.recordError(
              'OTP Verification Failed',
              StackTrace.current,
              fatal: false,
              information: [
                'Phone: $phoneE164',
                'Error Code: ${e.code}',
                'Error Message: ${e.message}',
                'Full Error: ${e.toString()}',
              ],
            );
          }
          completer.completeError(e);
        },
        codeSent: (verificationId, resendToken) {
          if (kDebugMode) {
            print(
              '[PhonePinAuth] DIAGNOSTIC: codeSent callback - verificationId=${verificationId != null ? 'present' : 'null'}, resendToken=${resendToken != null ? 'present' : 'null'}',
            );
            FirebaseCrashlytics.instance.log(
              'OTP_CODE_SENT: verificationId=${verificationId != null ? 'present' : 'null'}',
            );
          }
          _lastVerificationId = verificationId;

          if (kDebugMode) {
            print(
              '[PhonePinAuth] Firebase Auth phone verification started successfully: verificationId isNull=${_lastVerificationId == null}',
            );
          }

          completer.complete();
        },
        codeAutoRetrievalTimeout: (vid) {
          if (kDebugMode) {
            print('[PhonePinAuth] DIAGNOSTIC: codeAutoRetrievalTimeout callback - verificationId=$vid');
            FirebaseCrashlytics.instance.log('OTP_AUTO_RETRIEVAL_TIMEOUT: verificationId=$vid');
          }
          _lastVerificationId = vid;
        },
      );

      if (kDebugMode) {
        print('[PhonePinAuth] DIAGNOSTIC: verifyPhoneNumber() call initiated, waiting for callbacks...');
      }

      await completer.future;

      if (kDebugMode) {
        print(
          '[PhonePinAuth] DIAGNOSTIC: ensurePhoneSession() completed successfully, verificationId=$_lastVerificationId',
        );
        FirebaseCrashlytics.instance.log('OTP_SEND_SUCCESS: verificationId=$_lastVerificationId');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[PhonePinAuth] DIAGNOSTIC: ensurePhoneSession() EXCEPTION: ${e.runtimeType} - $e');
        print('[PhonePinAuth] DIAGNOSTIC: Stacktrace: $stackTrace');
        FirebaseCrashlytics.instance.log('OTP_SEND_EXCEPTION: ${e.runtimeType} - $e');
        // Record the exception for analysis
        FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          fatal: false,
          information: ['Phone: $phoneE164', 'Operation: ensurePhoneSession'],
        );
      }
      rethrow;
    }
  }

  Future<void> confirmOtp(String smsCode) async {
    if (kDebugMode) {
      print('[PhonePinAuth] confirmOtp() called with smsCode=$smsCode');
    }

    final vid = _lastVerificationId;
    if (vid == null) {
      if (kDebugMode) {
        print('[PhonePinAuth] ERROR: No verification ID available');
      }
      throw Exception('No verification id');
    }

    if (kDebugMode) {
      print('[PhonePinAuth] Creating credential with verificationId=$vid');
    }

    try {
      final cred = PhoneAuthProvider.credential(verificationId: vid, smsCode: smsCode);

      if (kDebugMode) {
        print('[PhonePinAuth] Signing in with credential...');
      }

      await _auth.signInWithCredential(cred);

      if (kDebugMode) {
        print('[PhonePinAuth] Sign-in successful!');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PhonePinAuth] Sign-in FAILED: ${e.runtimeType} - $e');
      }
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
      print('[PhonePinAuth] Verifying PIN for phone: $phoneE164');
    }

    // GUARD: Ensure phone is in E.164 format
    if (!phoneE164.startsWith('+')) {
      if (kDebugMode) {
        print('[PhonePinAuth] ERROR: Phone not in E.164 format: $phoneE164');
      }
      throw ArgumentError('Phone must be in E.164 format (starting with +)');
    }

    // Check if user is already signed in
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.phoneNumber == phoneE164) {
      if (kDebugMode) {
        print('[PhonePinAuth] User already signed in with matching phone');
      }
      return true;
    }

    try {
      // Call Cloud Function to verify PIN and get custom token
      final callable = FirebaseFunctions.instance.httpsCallable('createCustomToken');

      // Determine userType from collection name
      final userType = userCollection == 'drivers' ? 'driver' : 'user';

      final result = await callable.call<Map<String, dynamic>>({
        'phoneE164': phoneE164,
        'pin': pin,
        'userType': userType, // NEW PARAMETER
      });

      final token = result.data['token'] as String?;
      final uid = result.data['uid'] as String?;

      if (token == null) {
        if (kDebugMode) {
          print('[PhonePinAuth] No token returned from createCustomToken');
        }
        return false;
      }

      if (kDebugMode) {
        print('[PhonePinAuth] Custom token received, signing in user: $uid');
      }

      // Sign in with custom token
      await _auth.signInWithCustomToken(token);

      if (kDebugMode) {
        print('[PhonePinAuth] Successfully signed in with custom token');
      }

      return true;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('[PhonePinAuth] Cloud Function error: ${e.code} - ${e.message}');
      }
      return false;
    } on Object catch (e) {
      if (kDebugMode) {
        print('[PhonePinAuth] Error verifying PIN: $e');
      }
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
      // Use Cloud Function instead of direct query to avoid Firestore permission issues
      // Cloud Functions bypass security rules and can safely check phone existence
      final callable = FirebaseFunctions.instance.httpsCallable('checkPhoneExists');

      // Determine userType from collection name
      final userType = userCollection == 'drivers' ? 'driver' : 'user';

      final result = await callable.call<Map<String, dynamic>>({
        'phoneE164': phoneE164,
        'userType': userType,
      });

      return result.data['exists'] as bool? ?? false;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('[PhonePinAuth] Cloud Function error checking phone: ${e.code} - ${e.message}');
      }
      // On error, return false to prevent blocking user flow
      return false;
    } on Object catch (e) {
      if (kDebugMode) {
        print('[PhonePinAuth] Error checking phone existence: $e');
      }
      return false;
    }
  }

  Future<void> signOut() => _auth.signOut();
}
