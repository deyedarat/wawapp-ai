import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wawapp_client/features/auth/services/phone_auth_service.dart';

import 'phone_auth_service_test.mocks.dart';

@GenerateMocks([FirebaseAuth, UserCredential])
void main() {
  group('PhoneAuthService', () {
    late MockFirebaseAuth mockAuth;
    late PhoneAuthService service;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      service = PhoneAuthService(auth: mockAuth);
    });

    group('isValidPhoneNumber', () {
      test('returns true for valid international phone numbers', () {
        expect(PhoneAuthService.isValidPhoneNumber('+1234567890'), true);
        expect(PhoneAuthService.isValidPhoneNumber('+33123456789'), true);
        expect(PhoneAuthService.isValidPhoneNumber('+966501234567'), true);
      });

      test('returns false for invalid phone numbers', () {
        expect(PhoneAuthService.isValidPhoneNumber('1234567890'), false);
        expect(PhoneAuthService.isValidPhoneNumber('+'), false);
        expect(PhoneAuthService.isValidPhoneNumber(''), false);
        expect(PhoneAuthService.isValidPhoneNumber('abc'), false);
        expect(PhoneAuthService.isValidPhoneNumber('+0123456789'), false);
      });
    });

    group('verifyPhoneNumber', () {
      test('calls Firebase verifyPhoneNumber with correct parameters', () async {
        const phoneNumber = '+1234567890';
        String? capturedVerificationId;
        String? capturedError;

        when(mockAuth.verifyPhoneNumber(
          phoneNumber: anyNamed('phoneNumber'),
          verificationCompleted: anyNamed('verificationCompleted'),
          verificationFailed: anyNamed('verificationFailed'),
          codeSent: anyNamed('codeSent'),
          timeout: anyNamed('timeout'),
        )).thenAnswer((invocation) async {
          final codeSent = invocation.namedArguments[#codeSent] as Function;
          codeSent('test-verification-id', null);
        });

        await service.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          onCodeSent: (id) => capturedVerificationId = id,
          onError: (error) => capturedError = error,
        );

        expect(capturedVerificationId, 'test-verification-id');
        expect(capturedError, isNull);
        verify(mockAuth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: anyNamed('verificationCompleted'),
          verificationFailed: anyNamed('verificationFailed'),
          codeSent: anyNamed('codeSent'),
          timeout: const Duration(seconds: PhoneAuthService.otpTimeoutSeconds),
        )).called(1);
      });

      test('handles Firebase auth exceptions', () async {
        const phoneNumber = '+1234567890';
        String? capturedError;

        when(mockAuth.verifyPhoneNumber(
          phoneNumber: anyNamed('phoneNumber'),
          verificationCompleted: anyNamed('verificationCompleted'),
          verificationFailed: anyNamed('verificationFailed'),
          codeSent: anyNamed('codeSent'),
          timeout: anyNamed('timeout'),
        )).thenAnswer((invocation) async {
          final verificationFailed = invocation.namedArguments[#verificationFailed] as Function;
          verificationFailed(FirebaseAuthException(code: 'invalid-phone-number'));
        });

        await service.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          onCodeSent: (_) {},
          onError: (error) => capturedError = error,
        );

        expect(capturedError, isNotNull);
      });
    });

    group('verifyOTP', () {
      test('creates credential and signs in with Firebase', () async {
        const verificationId = 'test-verification-id';
        const otpCode = '123456';
        final mockCredential = MockUserCredential();

        when(mockAuth.signInWithCredential(any))
            .thenAnswer((_) async => mockCredential);

        final result = await service.verifyOTP(
          verificationId: verificationId,
          otpCode: otpCode,
        );

        expect(result, mockCredential);
        verify(mockAuth.signInWithCredential(any)).called(1);
      });
    });
  });
}