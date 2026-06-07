import '../constants/app_constants.dart';

/// Validation utilities for form inputs.
class Validators {
  Validators._();

  /// Validates a Mauritanian phone number.
  /// Format: +222XXXXXXXX (8 digits after country code)
  static bool isValidPhone(String phone) {
    // Remove spaces and dashes
    final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');

    // Check with country code
    if (cleaned.startsWith('+222')) {
      return cleaned.length == 12 && RegExp(r'^\+222[234]\d{7}$').hasMatch(cleaned);
    }

    // Check without country code
    if (cleaned.length == AppConstants.phoneNumberLength) {
      return RegExp(r'^[234]\d{7}$').hasMatch(cleaned);
    }

    return false;
  }

  /// Formats a phone number to include country code.
  static String formatPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.startsWith('+222')) {
      return cleaned;
    }
    if (cleaned.startsWith('222')) {
      return '+$cleaned';
    }
    return '${AppConstants.countryCode}$cleaned';
  }

  /// Validates a name (at least 2 characters).
  static bool isValidName(String name) {
    return name.trim().length >= 2;
  }

  /// Validates an OTP code.
  static bool isValidOtp(String otp) {
    return otp.length == AppConstants.otpLength &&
        RegExp(r'^\d+$').hasMatch(otp);
  }

  /// Validates a price value.
  static bool isValidPrice(String price) {
    final value = double.tryParse(price);
    return value != null && value > 0;
  }

  /// Validates a quantity value.
  static bool isValidQuantity(String quantity) {
    final value = int.tryParse(quantity);
    return value != null && value > 0;
  }
}
