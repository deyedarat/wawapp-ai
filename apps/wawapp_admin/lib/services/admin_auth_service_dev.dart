/**
 * Admin Authentication Service - Development Mode
 * FOR DEVELOPMENT ONLY - Bypasses admin claim check
 * DO NOT USE IN PRODUCTION
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AdminAuthServiceDev {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if current user is an admin (DEV MODE - always returns true if authenticated)
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    return user != null;
  }

  /// Sign in with email and password (DEV MODE - no admin check)
  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Sign in failed');
      }

      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found with this email');
        case 'wrong-password':
          throw Exception('Incorrect password');
        case 'invalid-email':
          throw Exception('Invalid email address');
        case 'user-disabled':
          throw Exception('This account has been disabled');
        default:
          throw Exception('Authentication error: ${e.message}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get admin user profile data
  Future<Map<String, dynamic>?> getAdminProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('admins').doc(user.uid).get();
      if (!doc.exists) {
        // Return basic data from Firebase Auth
        return {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? 'Admin (Dev)',
          'photoURL': user.photoURL,
        };
      }
      return doc.data();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching admin profile: $e');
      }
      return null;
    }
  }

  /// Request password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('Invalid email address');
        case 'user-not-found':
          throw Exception('No user found with this email');
        default:
          throw Exception('Error sending reset email: ${e.message}');
      }
    }
  }

  /// Register new user (DEV MODE ONLY)
  Future<bool> registerWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Registration failed');
      }

      // Create admin profile in Firestore
      await _firestore.collection('admins').doc(credential.user!.uid).set({
        'email': email,
        'displayName': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'admin',
        'isDev': true,
      });

      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('This email is already registered');
        case 'invalid-email':
          throw Exception('Invalid email address');
        case 'weak-password':
          throw Exception('Password is too weak');
        default:
          throw Exception('Registration error: ${e.message}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
