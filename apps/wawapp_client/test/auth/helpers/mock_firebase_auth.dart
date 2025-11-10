import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Mock FirebaseAuth for testing
class MockFirebaseAuth implements FirebaseAuth {
  MockFirebaseAuth({User? initialUser}) : _currentUser = initialUser;

  User? _currentUser;
  final _authStateController = StreamController<User?>.broadcast();

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _authStateController.stream;

  @override
  Stream<User?> userChanges() => _authStateController.stream;

  @override
  Stream<User?> idTokenChanges() => _authStateController.stream;

  /// Test helper: simulate user sign in
  void signInUser(User user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  /// Test helper: simulate user sign out
  void signOutUser() {
    _currentUser = null;
    _authStateController.add(null);
  }

  /// Clean up
  void dispose() {
    _authStateController.close();
  }

  @override
  Future<void> signOut() async {
    signOutUser();
  }

  // Unimplemented methods - throw if accidentally called
  @override
  FirebaseApp get app => throw UnimplementedError();

  @override
  set app(FirebaseApp? newApp) => throw UnimplementedError();

  @override
  String? get customAuthDomain => null;

  @override
  set customAuthDomain(String? domain) => throw UnimplementedError();

  @override
  String? get tenantId => null;

  @override
  set tenantId(String? tenant) => throw UnimplementedError();

  @override
  Future<void> applyActionCode(String code) => throw UnimplementedError();

  @override
  Future<ActionCodeInfo> checkActionCode(String code) =>
      throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) =>
      throw UnimplementedError();

  @override
  String? get languageCode => null;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendSignInLinkToEmail({
    required String email,
    required ActionCodeSettings actionCodeSettings,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> setLanguageCode(String? languageCode) =>
      throw UnimplementedError();

  @override
  Future<void> setPersistence(Persistence persistence) =>
      throw UnimplementedError();

  @override
  Future<void> setSettings({
    bool appVerificationDisabledForTesting = false,
    String? userAccessGroup,
    String? phoneNumber,
    String? smsCode,
    bool? forceRecaptchaFlow,
  }) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> signInAnonymously() => throw UnimplementedError();

  @override
  Future<UserCredential> signInWithCredential(
    AuthCredential credential,
  ) async {
    // For testing purposes, we can simulate sign in
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signInWithCustomToken(String token) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) =>
      throw UnimplementedError();

  @override
  Future<ConfirmationResult> signInWithPhoneNumber(
    String phoneNumber, [
    RecaptchaVerifier? verifier,
  ]) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithRedirect(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<String> verifyPasswordResetCode(String code) async =>
      throw UnimplementedError();

  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    String? autoRetrievedSmsCodeForTesting,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
    MultiFactorSession? multiFactorSession,
  }) =>
      throw UnimplementedError();

  @override
  bool isSignInWithEmailLink(String emailLink) => throw UnimplementedError();

  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<void> useAuthEmulator(String host, int port,
      {bool automaticHostMapping = true}) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> getRedirectResult() => throw UnimplementedError();

  @override
  Future<void> initializeRecaptchaConfig() => throw UnimplementedError();

  @override
  Future<void> revokeTokenWithAuthorizationCode(String authorizationCode) =>
      throw UnimplementedError();

  @override
  Map<String, dynamic> get pluginConstants => throw UnimplementedError();

  @override
  void useEmulator(String host, int port) => throw UnimplementedError();
}
