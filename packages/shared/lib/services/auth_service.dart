import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../constants/firestore_paths.dart';

/// Service handling Firebase Authentication with phone OTP.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Current Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether a user is currently signed in.
  bool get isSignedIn => currentUser != null;

  /// Sends OTP to the given phone number.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Signs in with the OTP code.
  Future<UserCredential> signInWithOTP({
    required String verificationId,
    required String otpCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otpCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Creates or updates user profile in Firestore.
  Future<void> createOrUpdateUser(UserModel user) async {
    await _firestore
        .collection(FirestorePaths.users)
        .doc(user.uid)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  /// Gets user profile from Firestore.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection(FirestorePaths.users).doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  /// Gets user by phone number.
  Future<UserModel?> getUserByPhone(String phoneNumber) async {
    final query = await _firestore
        .collection(FirestorePaths.users)
        .where(FirestorePaths.fieldPhoneNumber, isEqualTo: phoneNumber)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return UserModel.fromFirestore(query.docs.first);
    }
    return null;
  }

  /// Updates the FCM token for the current user.
  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore.collection(FirestorePaths.users).doc(uid).update({
      FirestorePaths.fieldFcmToken: token,
    });
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Deletes the current user account.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user != null) {
      await _firestore.collection(FirestorePaths.users).doc(user.uid).delete();
      await user.delete();
    }
  }
}
