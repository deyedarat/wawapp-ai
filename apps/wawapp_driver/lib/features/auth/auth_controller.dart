import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthController {
  final FirebaseAuth _auth;

  AuthController(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signOut() => _auth.signOut();
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(FirebaseAuth.instance);
});
