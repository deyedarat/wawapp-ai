import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:auth_shared/auth_shared.dart';
import 'package:wawapp_driver/features/auth/otp_screen.dart';
import 'package:wawapp_driver/features/auth/providers/auth_service_provider.dart'
    as driver_auth;

@GenerateMocks([PhonePinAuth, FirebaseAuth])
import 'otp_screen_test.mocks.dart';

void main() {
  group('OtpScreen Widget Tests', () {
    late ProviderContainer container;
    late MockPhonePinAuth mockPhonePinAuth;
    late MockFirebaseAuth mockFirebaseAuth;

    setUp(() {
      mockPhonePinAuth = MockPhonePinAuth();
      mockFirebaseAuth = MockFirebaseAuth();

      when(mockFirebaseAuth.currentUser).thenReturn(null);
      when(mockFirebaseAuth.authStateChanges())
          .thenAnswer((_) => Stream.value(null));
      when(mockPhonePinAuth.hasPinHash()).thenAnswer((_) async => false);

      container = ProviderContainer(
        overrides: [
          driver_auth.phonePinAuthServiceProvider
              .overrideWithValue(mockPhonePinAuth),
          driver_auth.authProvider.overrideWith((ref) =>
              driver_auth.AuthNotifier(mockPhonePinAuth, mockFirebaseAuth)),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('renders OTP input field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: OtpScreen(),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('TextField accepts numeric input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: OtpScreen(),
          ),
        ),
      );

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.keyboardType, TextInputType.number);
      expect(textFieldWidget.maxLength, 6);

      await tester.enterText(textField, '123456');
      await tester.pump();

      expect(find.text('123456'), findsOneWidget);
    });

    testWidgets('has proper layout structure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: OtpScreen(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Padding), findsWidgets);
      expect(find.byType(Column), findsOneWidget);
    });
  });
}
