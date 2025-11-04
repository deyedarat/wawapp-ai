import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:wawapp_client/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:wawapp_client/features/auth/presentation/bloc/auth_event.dart';
import 'package:wawapp_client/features/auth/presentation/bloc/auth_state.dart';
import 'package:wawapp_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:wawapp_client/features/auth/domain/entities/user_entity.dart';
import 'package:wawapp_client/features/auth/services/phone_auth_service.dart';
import 'package:wawapp_client/features/auth/utils/lockout_manager.dart';

import 'auth_bloc_test.mocks.dart';

@GenerateMocks([AuthRepository, PhoneAuthService, LockoutManager, UserEntity])
void main() {
  group('AuthBloc', () {
    late MockAuthRepository mockRepository;
    late MockPhoneAuthService mockPhoneService;
    late MockLockoutManager mockLockoutManager;
    late AuthBloc authBloc;

    setUp(() {
      mockRepository = MockAuthRepository();
      mockPhoneService = MockPhoneAuthService();
      mockLockoutManager = MockLockoutManager();
      authBloc = AuthBloc(
        authRepository: mockRepository,
        phoneService: mockPhoneService,
        lockoutManager: mockLockoutManager,
      );
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, AuthInitial());
    });

    group('SendOTPEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, OTPSent] when OTP is sent successfully',
        build: () {
          when(mockPhoneService.verifyPhoneNumber(
            phoneNumber: anyNamed('phoneNumber'),
            onCodeSent: anyNamed('onCodeSent'),
            onError: anyNamed('onError'),
          )).thenAnswer((invocation) async {
            final onCodeSent = invocation.namedArguments[#onCodeSent] as Function;
            onCodeSent('test-verification-id');
          });
          return authBloc;
        },
        act: (bloc) => bloc.add(const SendOTPEvent('+1234567890')),
        expect: () => [
          AuthLoading(),
          const OTPSent(
            verificationId: 'test-verification-id',
            phoneNumber: '+1234567890',
          ),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthError] when phone number is invalid',
        build: () => authBloc,
        act: (bloc) => bloc.add(const SendOTPEvent('invalid')),
        expect: () => [
          AuthLoading(),
          const AuthError('Invalid phone number format'),
        ],
      );
    });

    group('LoginWithPinEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthSuccess] when login succeeds',
        build: () {
          final mockUser = MockUserEntity();
          when(mockLockoutManager.getLockoutDuration(any))
              .thenAnswer((_) async => null);
          when(mockRepository.loginWithPhoneAndPin(
            phoneNumber: anyNamed('phoneNumber'),
            pin: anyNamed('pin'),
          )).thenAnswer((_) async => mockUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const LoginWithPinEvent('+1234567890', '1234')),
        expect: () => [
          AuthLoading(),
          isA<AuthSuccess>(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AccountLocked] when account is locked',
        build: () {
          when(mockLockoutManager.getLockoutDuration(any))
              .thenAnswer((_) async => const Duration(minutes: 5));
          return authBloc;
        },
        act: (bloc) => bloc.add(const LoginWithPinEvent('+1234567890', '1234')),
        expect: () => [
          AuthLoading(),
          const AccountLocked(Duration(minutes: 5)),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'records failed attempt on login error',
        build: () {
          when(mockLockoutManager.getLockoutDuration(any))
              .thenAnswer((_) async => null);
          when(mockRepository.loginWithPhoneAndPin(
            phoneNumber: anyNamed('phoneNumber'),
            pin: anyNamed('pin'),
          )).thenThrow(Exception('Invalid PIN'));
          when(mockLockoutManager.recordFailedAttempt(any))
              .thenAnswer((_) async => {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const LoginWithPinEvent('+1234567890', '1234')),
        verify: (_) {
          verify(mockLockoutManager.recordFailedAttempt('+1234567890')).called(1);
        },
        expect: () => [
          AuthLoading(),
          const AuthError('Exception: Invalid PIN'),
        ],
      );
    });

    group('CheckAuthStatusEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthSuccess] when user is authenticated',
        build: () {
          final mockUser = MockUserEntity();
          when(mockRepository.getCurrentUser())
              .thenAnswer((_) async => mockUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(CheckAuthStatusEvent()),
        expect: () => [isA<AuthSuccess>()],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [Unauthenticated] when no user is found',
        build: () {
          when(mockRepository.getCurrentUser())
              .thenAnswer((_) async => null);
          return authBloc;
        },
        act: (bloc) => bloc.add(CheckAuthStatusEvent()),
        expect: () => [Unauthenticated()],
      );
    });

    group('SignOutEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [Unauthenticated] when sign out succeeds',
        build: () {
          when(mockRepository.signOut()).thenAnswer((_) async => {});
          return authBloc;
        },
        act: (bloc) => bloc.add(SignOutEvent()),
        expect: () => [Unauthenticated()],
      );
    });
  });
}
