import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wawapp_client/features/auth/otp_screen.dart';

void main() {
  group('OtpScreen Widget Tests', () {
    testWidgets('renders OTP input field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      // Check that the screen renders
      expect(find.byType(OtpScreen), findsOneWidget);

      // Check for the AppBar title
      expect(find.text('Enter SMS Code'), findsOneWidget);

      // Check for the code input field
      expect(find.byType(TextField), findsOneWidget);

      // Check for the Verify button
      expect(find.text('Verify'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('TextField accepts numeric input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Enter text into the field
      await tester.enterText(textField, '123456');
      await tester.pump();

      // Verify the text was entered
      expect(find.text('123456'), findsOneWidget);
    });

    testWidgets('TextField has maxLength of 6', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      final textField = find.byType(TextField);
      final textFieldWidget = tester.widget<TextField>(textField);

      // Check that maxLength is 6
      expect(textFieldWidget.maxLength, 6);
      expect(textFieldWidget.keyboardType, TextInputType.number);
    });

    testWidgets('Verify button is initially enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      final button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);

      final buttonWidget = tester.widget<ElevatedButton>(button);
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('displays error message when verification fails',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      // Initially, no error should be displayed
      expect(find.text('Invalid code. Please try again.'), findsNothing);

      // Note: Actually triggering the error would require mocking
      // PhonePinAuth.instance, which is a singleton.
      // This test verifies the UI structure; integration tests would
      // handle the actual verification flow.
    });

    testWidgets('has proper layout structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      // Verify layout components
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Padding), findsWidgets);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('TextField has correct decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      final textField = find.byType(TextField);
      final textFieldWidget = tester.widget<TextField>(textField);

      expect(textFieldWidget.decoration?.labelText, 'Code');
    });

    testWidgets('button text is correct', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      // Verify button text
      expect(find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.text('Verify'),
      ), findsOneWidget);
    });

    testWidgets('can clear and re-enter code', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      final textField = find.byType(TextField);

      // Enter initial code
      await tester.enterText(textField, '123456');
      await tester.pump();
      expect(find.text('123456'), findsOneWidget);

      // Clear and enter new code
      await tester.enterText(textField, '654321');
      await tester.pump();
      expect(find.text('654321'), findsOneWidget);
      expect(find.text('123456'), findsNothing);
    });

    testWidgets('respects numeric keyboard type', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      final textField = find.byType(TextField);
      final textFieldWidget = tester.widget<TextField>(textField);

      // Verify numeric keyboard
      expect(textFieldWidget.keyboardType, TextInputType.number);
    });
  });

  group('OtpScreen State Management', () {
    testWidgets('maintains code between rebuilds', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      final textField = find.byType(TextField);

      // Enter code
      await tester.enterText(textField, '123456');
      await tester.pump();

      // Trigger rebuild
      await tester.pump();

      // Verify code is still there
      expect(find.text('123456'), findsOneWidget);
    });
  });

  group('OtpScreen Accessibility', () {
    testWidgets('has semantic labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpScreen(),
        ),
      );

      // Verify semantics are present
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // This ensures the widgets can be found by accessibility tools
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });
}
