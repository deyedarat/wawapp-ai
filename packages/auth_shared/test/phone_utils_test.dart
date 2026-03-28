import 'package:flutter_test/flutter_test.dart';
import 'package:auth_shared/auth_shared.dart';

void main() {
  group('MauritaniaPhoneUtils - Local Number Validation', () {
    test('validates correct 8-digit numbers starting with 2, 3, or 4', () {
      // Chinguitel (starts with 2)
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('22123456'), true);
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('29876543'), true);
      
      // Mattel (starts with 3)
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('33456789'), true);
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('38765432'), true);
      
      // Mauritel (starts with 4)
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('45678901'), true);
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('49876543'), true);
    });

    test('rejects numbers with wrong length', () {
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('2212345'), false); // 7 digits
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('221234567'), false); // 9 digits
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('22'), false); // 2 digits
    });

    test('rejects numbers with invalid first digit', () {
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('12345678'), false); // starts with 1
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('52345678'), false); // starts with 5
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('92345678'), false); // starts with 9
    });

    test('rejects non-digit characters', () {
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('2234567a'), false);
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('22-34-56-78'), false);
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('22.345.678'), false);
    });

    test('handles whitespace in input', () {
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('  22123456  '), true);
      expect(MauritaniaPhoneUtils.isValidMauritaniaLocalNumber('22 12 34 56'), true);
    });
  });

  group('MauritaniaPhoneUtils - E.164 Validation', () {
    test('validates correct E.164 format', () {
      expect(MauritaniaPhoneUtils.isValidMauritaniaE164('+22222123456'), true);
      expect(MauritaniaPhoneUtils.isValidMauritaniaE164('+22233456789'), true);
      expect(MauritaniaPhoneUtils.isValidMauritaniaE164('+22245678901'), true);
    });

    test('rejects E.164 without +222 prefix', () {
      expect(MauritaniaPhoneUtils.isValidMauritaniaE164('22222123456'), false);
      expect(MauritaniaPhoneUtils.isValidMauritaniaE164('+22122123456'), false); // wrong country code
    });

    test('rejects E.164 with invalid local part', () {
      expect(MauritaniaPhoneUtils.isValidMauritaniaE164('+22212345678'), false); // starts with 1
      expect(MauritaniaPhoneUtils.isValidMauritaniaE164('+2222212345'), false); // too short
      expect(MauritaniaPhoneUtils.isValidMauritaniaE164('+222221234567'), false); // too long
    });
  });

  group('MauritaniaPhoneUtils - E.164 Conversion', () {
    test('converts valid local number to E.164', () {
      expect(MauritaniaPhoneUtils.toMauritaniaE164('22123456'), '+22222123456');
      expect(MauritaniaPhoneUtils.toMauritaniaE164('33456789'), '+22233456789');
      expect(MauritaniaPhoneUtils.toMauritaniaE164('45678901'), '+22245678901');
    });

    test('returns E.164 if already in that format', () {
      expect(MauritaniaPhoneUtils.toMauritaniaE164('+22222123456'), '+22222123456');
      expect(MauritaniaPhoneUtils.toMauritaniaE164('+22233456789'), '+22233456789');
    });

    test('throws on invalid local number', () {
      expect(
        () => MauritaniaPhoneUtils.toMauritaniaE164('12345678'),
        throwsArgumentError,
      );
      expect(
        () => MauritaniaPhoneUtils.toMauritaniaE164('2212345'),
        throwsArgumentError,
      );
    });

    test('throws on invalid E.164 format', () {
      expect(
        () => MauritaniaPhoneUtils.toMauritaniaE164('+22112345678'),
        throwsArgumentError,
      );
    });
  });

  group('MauritaniaPhoneUtils - Local Number Extraction', () {
    test('extracts local number from E.164', () {
      expect(MauritaniaPhoneUtils.toLocalNumber('+22222123456'), '22123456');
      expect(MauritaniaPhoneUtils.toLocalNumber('+22233456789'), '33456789');
      expect(MauritaniaPhoneUtils.toLocalNumber('+22245678901'), '45678901');
    });

    test('returns null for invalid E.164', () {
      expect(MauritaniaPhoneUtils.toLocalNumber('+22112345678'), null);
      expect(MauritaniaPhoneUtils.toLocalNumber('22123456'), null);
    });
  });

  group('MauritaniaPhoneUtils - Formatting', () {
    test('formats local number with spaces', () {
      expect(MauritaniaPhoneUtils.formatLocalNumber('22123456'), '22 12 34 56');
      expect(MauritaniaPhoneUtils.formatLocalNumber('33456789'), '33 45 67 89');
      expect(MauritaniaPhoneUtils.formatLocalNumber('45678901'), '45 67 89 01');
    });

    test('returns input as-is for invalid length', () {
      expect(MauritaniaPhoneUtils.formatLocalNumber('123'), '123');
      expect(MauritaniaPhoneUtils.formatLocalNumber('123456789'), '123456789');
    });
  });

  group('MauritaniaPhoneUtils - Operator Detection', () {
    test('identifies operators from local numbers', () {
      expect(MauritaniaPhoneUtils.getOperatorName('22123456'), 'Chinguitel');
      expect(MauritaniaPhoneUtils.getOperatorName('33456789'), 'Mattel');
      expect(MauritaniaPhoneUtils.getOperatorName('45678901'), 'Mauritel');
    });

    test('identifies operators from E.164 numbers', () {
      expect(MauritaniaPhoneUtils.getOperatorName('+22222123456'), 'Chinguitel');
      expect(MauritaniaPhoneUtils.getOperatorName('+22233456789'), 'Mattel');
      expect(MauritaniaPhoneUtils.getOperatorName('+22245678901'), 'Mauritel');
    });

    test('returns null for invalid numbers', () {
      expect(MauritaniaPhoneUtils.getOperatorName('12345678'), null);
      expect(MauritaniaPhoneUtils.getOperatorName(''), null);
      expect(MauritaniaPhoneUtils.getOperatorName('+222'), null);
    });
  });

  group('MauritaniaPhoneUtils - Error Messages', () {
    test('provides appropriate error messages', () {
      expect(MauritaniaPhoneUtils.getValidationError(''), contains('إدخال رقم'));
      expect(MauritaniaPhoneUtils.getValidationError('223456'), contains('8 أرقام'));
      expect(MauritaniaPhoneUtils.getValidationError('223456789'), contains('8 أرقام'));
      expect(MauritaniaPhoneUtils.getValidationError('2234567a'), contains('أرقام فقط'));
      expect(MauritaniaPhoneUtils.getValidationError('12345678'), contains('يبدأ بـ'));
    });
  });
}
