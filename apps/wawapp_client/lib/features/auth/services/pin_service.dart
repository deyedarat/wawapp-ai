import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PinService {
  static bool isValidPin(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  static Future<String> hashPin(String pin, String salt) async {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<bool> verifyPin(String pin, String hash, String salt) async {
    final computedHash = await hashPin(pin, salt);
    return computedHash == hash;
  }
}