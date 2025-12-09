/**
 * Admin Authentication Service
 * Handles admin-specific authentication and role verification
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if current user is an admin
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Get fresh ID token to check custom claims
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims;
      
      // Check for isAdmin custom claim
      return claims?['isAdmin'] == true;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// Sign in with email and password
  /// Returns true if sign-in successful AND user is admin
  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Sign in failed');
      }

      // Verify admin role
      final isAdminUser = await isAdmin();
      if (!isAdminUser) {
        // Sign out if not admin
        await signOut();
        throw Exception('Access denied: Admin privileges required');
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
          'displayName': user.displayName ?? 'Admin',
          'photoURL': user.photoURL,
        };
      }
      return doc.data();
    } catch (e) {
      print('Error fetching admin profile: $e');
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
}
