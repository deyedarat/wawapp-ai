import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a widget with ProviderScope and optional provider overrides
Future<void> pumpWithProviders(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: widget,
      ),
    ),
  );
}

/// Helper to create a ProviderContainer for testing
ProviderContainer createContainer({
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: overrides,
  );
}

/// Fake Firebase User for testing
class FakeUser implements User {
  FakeUser({
    required this.uid,
    this.phoneNumber,
    this.email,
    this.displayName,
  });

  @override
  final String uid;

  @override
  final String? phoneNumber;

  @override
  final String? email;

  @override
  final String? displayName;

  @override
  bool get emailVerified => false;

  @override
  bool get isAnonymous => false;

  @override
  UserMetadata get metadata => throw UnimplementedError();

  @override
  List<UserInfo> get providerData => [];

  @override
  String? get refreshToken => null;

  @override
  String? get tenantId => null;

  @override
  String? get photoURL => null;

  @override
  MultiFactor get multiFactor => throw UnimplementedError();

  @override
  Future<void> delete() => throw UnimplementedError();

  @override
  Future<String> getIdToken([bool forceRefresh = false]) =>
      throw UnimplementedError();

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) =>
      throw UnimplementedError();

  @override
  Future<ConfirmationResult> linkWithPhoneNumber(
    String phoneNumber, [
    RecaptchaVerifier? verifier,
  ]) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<void> linkWithRedirect(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<void> reauthenticateWithRedirect(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<void> reload() => Future.value();

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) =>
      throw UnimplementedError();

  @override
  Future<User> unlink(String providerId) => throw UnimplementedError();

  @override
  Future<void> updateEmail(String newEmail) => throw UnimplementedError();

  @override
  Future<void> updatePassword(String newPassword) => throw UnimplementedError();

  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) =>
      throw UnimplementedError();

  @override
  Future<void> updatePhotoURL(String? photoURL) => throw UnimplementedError();

  @override
  Future<void> updateDisplayName(String? displayName) =>
      throw UnimplementedError();

  @override
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> verifyBeforeUpdateEmail(
    String newEmail, [
    ActionCodeSettings? actionCodeSettings,
  ]) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> reauthenticateWithProvider(
    AuthProvider provider,
  ) =>
      throw UnimplementedError();
}
