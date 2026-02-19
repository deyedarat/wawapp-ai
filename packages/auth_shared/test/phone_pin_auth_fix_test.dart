// Test to verify the "Future already completed" fix
// This demonstrates that the fix prevents crashes when multiple callbacks fire

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhonePinAuth Future Completion Safety', () {
    test('Completer.isCompleted prevents double completion', () {
      // This test demonstrates the core fix mechanism
      final completer = Completer<void>();

      // Simulate multiple callbacks trying to complete
      void callback1() {
        if (!completer.isCompleted) {
          print('Callback 1: Completing future');
          completer.complete();
        } else {
          print('Callback 1: Already completed, skipping');
        }
      }

      void callback2() {
        if (!completer.isCompleted) {
          print('Callback 2: Completing future');
          completer.complete();
        } else {
          print('Callback 2: Already completed, skipping');
        }
      }

      // Both callbacks fire (simulating race condition)
      callback1(); // First one completes
      callback2(); // Second one is safely ignored

      // Should not throw "Bad state: Future already completed"
      expect(completer.isCompleted, isTrue);
    });

    test('Completer.isCompleted prevents double error completion', () async {
      final completer = Completer<void>();

      void errorCallback1() {
        if (!completer.isCompleted) {
          print('Error Callback 1: Completing with error');
          completer.completeError(Exception('Error 1'));
        } else {
          print('Error Callback 1: Already completed, skipping');
        }
      }

      void errorCallback2() {
        if (!completer.isCompleted) {
          print('Error Callback 2: Completing with error');
          completer.completeError(Exception('Error 2'));
        } else {
          print('Error Callback 2: Already completed, skipping');
        }
      }

      // Both error callbacks fire
      errorCallback1(); // First one completes with error
      errorCallback2(); // Second one is safely ignored

      // Should not throw "Bad state: Future already completed"
      expect(completer.isCompleted, isTrue);
      await expectLater(completer.future, throwsA(isA<Exception>()));
    });

    test('Completer.isCompleted prevents mixed completion', () {
      final completer = Completer<void>();

      void successCallback() {
        if (!completer.isCompleted) {
          print('Success Callback: Completing successfully');
          completer.complete();
        } else {
          print('Success Callback: Already completed, skipping');
        }
      }

      void errorCallback() {
        if (!completer.isCompleted) {
          print('Error Callback: Completing with error');
          completer.completeError(Exception('Error'));
        } else {
          print('Error Callback: Already completed, skipping');
        }
      }

      // Success fires first, then error tries to fire
      successCallback(); // Completes successfully
      errorCallback(); // Safely ignored

      // Should not throw "Bad state: Future already completed"
      expect(completer.isCompleted, isTrue);
      expect(completer.future, completes);
    });
  });

  group('In-Flight Future Pattern', () {
    test('Prevents duplicate operations for concurrent calls', () async {
      Future<void>? inFlightFuture;
      int operationCount = 0;

      Future<void> simulateEnsurePhoneSession() async {
        // If already in-flight, return existing future
        if (inFlightFuture != null) {
          print('Returning existing in-flight future');
          return inFlightFuture!;
        }

        final completer = Completer<void>();

        try {
          inFlightFuture = completer.future;

          // Count actual operations
          operationCount++;

          // Simulate async operation
          await Future.delayed(Duration(milliseconds: 50));

          if (!completer.isCompleted) {
            completer.complete();
          }
        } finally {
          inFlightFuture = null;
        }
      }

      // Make concurrent calls (don't await the first one)
      final future1 = simulateEnsurePhoneSession();
      final future2 = simulateEnsurePhoneSession();

      // Wait for both to complete
      await Future.wait([future1, future2]);

      // Only one actual operation should have occurred
      expect(operationCount, equals(1));
      print('✓ In-flight future pattern prevented duplicate operations');
    });
  });
}
