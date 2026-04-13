import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Safe Google Sign-In service with comprehensive error handling and crash prevention
///
/// This service prevents the common SignInHubActivity NullPointerException crash by:
/// 1. Preventing concurrent sign-in attempts (mutex pattern)
/// 2. Clearing cached account state before sign-in
/// 3. Comprehensive error handling for all failure modes
/// 4. Defensive logging for production debugging
///
/// Usage:
/// ```dart
/// final service = GoogleSignInService();
/// final userCredential = await service.signInWithGoogle();
/// ```
class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._();
  factory GoogleSignInService() => _instance;
  GoogleSignInService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Mutex to prevent concurrent sign-in attempts
  /// This prevents SignInHubActivity crashes caused by multiple simultaneous sign-in calls
  bool _isSigningIn = false;

  /// Safe Google Sign-In with comprehensive error handling
  ///
  /// Returns:
  /// - [UserCredential] on successful sign-in
  /// - [null] if user cancelled sign-in
  ///
  /// Throws:
  /// - [PlatformException] for platform-specific errors
  /// - [FirebaseAuthException] for Firebase Auth errors
  /// - [Exception] for other unexpected errors
  Future<UserCredential?> signInWithGoogle() async {
    // GUARD 1: Prevent concurrent sign-in attempts
    // This is critical to prevent SignInHubActivity crashes
    if (_isSigningIn) {
      if (kDebugMode) {
        print(
            '[GoogleSignIn] Sign-in already in progress, ignoring duplicate call');
      }
      FirebaseCrashlytics.instance
          .log('Prevented concurrent Google Sign-In attempt');
      return null;
    }

    _isSigningIn = true;

    try {
      if (kDebugMode) {
        print('[GoogleSignIn] Starting Google Sign-In flow');
      }
      FirebaseCrashlytics.instance.log('Google Sign-In flow started');

      // STEP 1: Sign out first to clear any cached broken state
      // This prevents issues with stale account data that can cause SignInHubActivity crashes
      await _googleSignIn.signOut();

      if (kDebugMode) {
        print('[GoogleSignIn] Cleared cached account state');
      }

      // STEP 2: Trigger Google Sign-In UI
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // GUARD 2: User cancelled sign-in
      if (googleUser == null) {
        if (kDebugMode) {
          print('[GoogleSignIn] User cancelled sign-in');
        }
        FirebaseCrashlytics.instance.log('Google Sign-In cancelled by user');
        return null;
      }

      if (kDebugMode) {
        print('[GoogleSignIn] User selected: ${googleUser.email}');
      }

      // STEP 3: Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // GUARD 3: Verify tokens are present
      // Missing tokens can cause downstream crashes
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        if (kDebugMode) {
          print('[GoogleSignIn] ERROR: Missing authentication tokens');
        }
        FirebaseCrashlytics.instance.recordError(
          'Google Sign-In failed: Missing tokens',
          StackTrace.current,
          fatal: false,
          information: [
            'Access Token: ${googleAuth.accessToken != null ? 'present' : 'null'}',
            'ID Token: ${googleAuth.idToken != null ? 'present' : 'null'}',
          ],
        );
        throw Exception('Failed to get authentication tokens');
      }

      // STEP 4: Create Firebase credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // STEP 5: Sign in to Firebase
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (kDebugMode) {
        print(
            '[GoogleSignIn] ✓ Successfully signed in: ${userCredential.user?.email}');
      }

      FirebaseCrashlytics.instance
          .log('Google Sign-In successful: ${userCredential.user?.uid}');

      return userCredential;
    } on PlatformException catch (e) {
      // Handle platform-specific errors (Android/iOS)
      if (kDebugMode) {
        print('[GoogleSignIn] PlatformException: ${e.code} - ${e.message}');
      }

      FirebaseCrashlytics.instance.recordError(
        'Google Sign-In PlatformException',
        StackTrace.current,
        fatal: false,
        information: [
          'Error Code: ${e.code}',
          'Error Message: ${e.message}',
          'Error Details: ${e.details}',
        ],
      );

      // Specific error handling
      if (e.code == 'sign_in_failed' || e.code == 'network_error') {
        // FALLBACK: Try sign-out to clear broken state
        if (kDebugMode) {
          print('[GoogleSignIn] Attempting fallback: sign-out to clear state');
        }

        try {
          await _googleSignIn.signOut();
          await Future.delayed(const Duration(milliseconds: 500));
          // Don't retry automatically to avoid infinite loop
          // Let user retry manually
        } catch (fallbackError) {
          if (kDebugMode) {
            print('[GoogleSignIn] Fallback failed: $fallbackError');
          }
        }
      }

      rethrow;
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Auth errors
      if (kDebugMode) {
        print('[GoogleSignIn] FirebaseAuthException: ${e.code} - ${e.message}');
      }

      FirebaseCrashlytics.instance.recordError(
        'Google Sign-In FirebaseAuthException',
        StackTrace.current,
        fatal: false,
        information: [
          'Error Code: ${e.code}',
          'Error Message: ${e.message}',
        ],
      );

      rethrow;
    } catch (e, stackTrace) {
      // Catch any other unexpected errors
      if (kDebugMode) {
        print('[GoogleSignIn] Unexpected error: $e');
      }

      FirebaseCrashlytics.instance.recordError(
        'Google Sign-In unexpected error',
        stackTrace,
        fatal: false,
        information: ['Error: $e'],
      );

      rethrow;
    } finally {
      // CRITICAL: Always release the mutex
      // This ensures subsequent sign-in attempts can proceed
      _isSigningIn = false;
      if (kDebugMode) {
        print('[GoogleSignIn] Sign-in flow completed, mutex released');
      }
    }
  }

  /// Sign out from Google and Firebase
  ///
  /// This is a best-effort operation - errors are logged but not thrown
  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);

      if (kDebugMode) {
        print('[GoogleSignIn] ✓ Signed out successfully');
      }
      FirebaseCrashlytics.instance.log('Google Sign-Out successful');
    } catch (e) {
      if (kDebugMode) {
        print('[GoogleSignIn] Error during sign-out: $e');
      }
      FirebaseCrashlytics.instance.log('Google Sign-Out error: $e');
      // Don't throw - sign-out should be best-effort
    }
  }

  /// Check if user is currently signed in with Google
  bool get isSignedIn => _auth.currentUser != null;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if a sign-in operation is currently in progress
  bool get isSigningIn => _isSigningIn;
}
