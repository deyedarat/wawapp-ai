import 'package:flutter_test/flutter_test.dart';
import 'package:wawapp_client/features/auth/services/pin_service.dart';

void main() {
  group('PinService', () {
    group('isValidPin', () {
      test('returns true for valid 4-digit PINs', () {
        expect(PinService.isValidPin('1234'), true);
        expect(PinService.isValidPin('0000'), true);
        expect(PinService.isValidPin('9999'), true);
      });

      test('returns false for invalid PINs', () {
        expect(PinService.isValidPin('123'), false);
        expect(PinService.isValidPin('12345'), false);
        expect(PinService.isValidPin('abcd'), false);
        expect(PinService.isValidPin(''), false);
        expect(PinService.isValidPin('12a4'), false);
      });
    });

    group('generateSalt', () {
      test('generates unique salts', () {
        final salt1 = PinService.generateSalt();
        final salt2 = PinService.generateSalt();
        
        expect(salt1, isNotEmpty);
        expect(salt2, isNotEmpty);
        expect(salt1, isNot(equals(salt2)));
      });

      test('generates base64 encoded salt', () {
        final salt = PinService.generateSalt();
        
        // Base64 should not contain invalid characters
        expect(RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(salt), true);
      });
    });

    group('hashPin and verifyPin', () {
      test('hashes PIN with salt consistently', () async {
        const pin = '1234';
        const salt = 'testSalt123';
        
        final hash1 = await PinService.hashPin(pin, salt);
        final hash2 = await PinService.hashPin(pin, salt);
        
        expect(hash1, equals(hash2));
        expect(hash1, isNotEmpty);
      });

      test('produces different hashes for different PINs', () async {
        const salt = 'testSalt123';
        
        final hash1 = await PinService.hashPin('1234', salt);
        final hash2 = await PinService.hashPin('5678', salt);
        
        expect(hash1, isNot(equals(hash2)));
      });

      test('produces different hashes for different salts', () async {
        const pin = '1234';
        
        final hash1 = await PinService.hashPin(pin, 'salt1');
        final hash2 = await PinService.hashPin(pin, 'salt2');
        
        expect(hash1, isNot(equals(hash2)));
      });

      test('verifyPin returns true for correct PIN', () async {
        const pin = '1234';
        const salt = 'testSalt123';
        
        final hash = await PinService.hashPin(pin, salt);
        final isValid = await PinService.verifyPin(pin, hash, salt);
        
        expect(isValid, true);
      });

      test('verifyPin returns false for incorrect PIN', () async {
        const correctPin = '1234';
        const incorrectPin = '5678';
        const salt = 'testSalt123';
        
        final hash = await PinService.hashPin(correctPin, salt);
        final isValid = await PinService.verifyPin(incorrectPin, hash, salt);
        
        expect(isValid, false);
      });

      test('verifyPin returns false for incorrect salt', () async {
        const pin = '1234';
        const correctSalt = 'correctSalt';
        const incorrectSalt = 'incorrectSalt';
        
        final hash = await PinService.hashPin(pin, correctSalt);
        final isValid = await PinService.verifyPin(pin, hash, incorrectSalt);
        
        expect(isValid, false);
      });
    });
  });
}