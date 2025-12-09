/// Mauritanian phone number validation and formatting utilities
/// 
/// Mauritania phone number rules:
/// - Local numbers are exactly 8 digits
/// - Operator prefixes:
///   - Mauritel: starts with 4
///   - Chinguitel: starts with 2  
///   - Mattel: starts with 3
/// - Country code: +222
/// - E.164 format: +222XXXXXXXX

class MauritaniaPhoneUtils {
  MauritaniaPhoneUtils._();

  /// Mauritania country code
  static const String countryCode = '+222';
  
  /// Local number length (without country code)
  static const int localNumberLength = 8;
  
  /// Valid first digits for Mauritanian operators
  static const List<String> validPrefixes = ['2', '3', '4'];
  
  /// Validates a Mauritanian local phone number (8 digits)
  /// 
  /// Returns true if:
  /// - Number is exactly 8 digits
  /// - First digit is 2, 3, or 4 (valid operator)
  /// 
  /// Example valid numbers: 22123456, 33456789, 45678901
  static bool isValidMauritaniaLocalNumber(String input) {
    // Remove any whitespace
    final cleaned = input.trim().replaceAll(RegExp(r'\s+'), '');
    
    // Check if it's exactly 8 digits
    if (cleaned.length != localNumberLength) {
      return false;
    }
    
    // Check if all characters are digits
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return false;
    }
    
    // Check if first digit is valid (2, 3, or 4)
    final firstDigit = cleaned[0];
    return validPrefixes.contains(firstDigit);
  }
  
  /// Validates a Mauritanian phone number in E.164 format
  /// 
  /// Returns true if:
  /// - Starts with +222
  /// - Followed by exactly 8 digits
  /// - First digit after +222 is 2, 3, or 4
  /// 
  /// Example: +22222123456
  static bool isValidMauritaniaE164(String input) {
    final cleaned = input.trim();
    
    // Check if it starts with +222
    if (!cleaned.startsWith(countryCode)) {
      return false;
    }
    
    // Extract the local part (after +222)
    final localPart = cleaned.substring(countryCode.length);
    
    // Validate the local part
    return isValidMauritaniaLocalNumber(localPart);
  }
  
  /// Converts a Mauritanian local number to E.164 format
  /// 
  /// Input: 8-digit local number (e.g., "22123456")
  /// Output: E.164 format (e.g., "+22222123456")
  /// 
  /// Throws ArgumentError if the input is not a valid local number
  static String toMauritaniaE164(String localNumber) {
    final cleaned = localNumber.trim().replaceAll(RegExp(r'\s+'), '');
    
    // If already in E.164 format, return as-is if valid
    if (cleaned.startsWith('+')) {
      if (isValidMauritaniaE164(cleaned)) {
        return cleaned;
      }
      throw ArgumentError(
        'Invalid Mauritanian phone number in E.164 format: $cleaned'
      );
    }
    
    // Validate local number format
    if (!isValidMauritaniaLocalNumber(cleaned)) {
      throw ArgumentError(
        'Invalid Mauritanian local phone number: $cleaned. '
        'Must be 8 digits starting with 2, 3, or 4.'
      );
    }
    
    return '$countryCode$cleaned';
  }
  
  /// Extracts local number from E.164 format
  /// 
  /// Input: "+22222123456"
  /// Output: "22123456"
  /// 
  /// Returns null if not a valid Mauritanian E.164 number
  static String? toLocalNumber(String e164) {
    final cleaned = e164.trim();
    
    if (!isValidMauritaniaE164(cleaned)) {
      return null;
    }
    
    return cleaned.substring(countryCode.length);
  }
  
  /// Formats a local number for display (with spaces for readability)
  /// 
  /// Input: "22123456"
  /// Output: "22 12 34 56"
  static String formatLocalNumber(String localNumber) {
    final cleaned = localNumber.trim().replaceAll(RegExp(r'\s+'), '');
    
    if (cleaned.length != localNumberLength) {
      return cleaned;
    }
    
    // Format as XX XX XX XX
    return '${cleaned.substring(0, 2)} ${cleaned.substring(2, 4)} '
           '${cleaned.substring(4, 6)} ${cleaned.substring(6, 8)}';
  }
  
  /// Gets the operator name from a phone number
  /// 
  /// Returns "Mauritel", "Chinguitel", "Mattel", or null if invalid
  static String? getOperatorName(String phoneNumber) {
    final cleaned = phoneNumber.trim().replaceAll(RegExp(r'\s+'), '');
    String firstDigit;
    
    if (cleaned.startsWith(countryCode)) {
      // E.164 format
      if (cleaned.length < countryCode.length + 1) return null;
      firstDigit = cleaned[countryCode.length];
    } else {
      // Local format
      if (cleaned.isEmpty) return null;
      firstDigit = cleaned[0];
    }
    
    switch (firstDigit) {
      case '2':
        return 'Chinguitel';
      case '3':
        return 'Mattel';
      case '4':
        return 'Mauritel';
      default:
        return null;
    }
  }
  
  /// User-friendly error messages for validation failures
  static String getValidationError(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'\s+'), '');
    
    if (cleaned.isEmpty) {
      return 'الرجاء إدخال رقم الهاتف';
    }
    
    if (cleaned.length < localNumberLength) {
      return 'رقم الهاتف يجب أن يكون 8 أرقام';
    }
    
    if (cleaned.length > localNumberLength && !cleaned.startsWith('+')) {
      return 'رقم الهاتف يجب أن يكون 8 أرقام فقط';
    }
    
    if (!RegExp(r'^\d+$').hasMatch(cleaned) && !cleaned.startsWith('+')) {
      return 'الرجاء إدخال أرقام فقط';
    }
    
    final firstDigit = cleaned[0];
    if (!validPrefixes.contains(firstDigit)) {
      return 'رقم غير صحيح. يجب أن يبدأ بـ 2 (شنقيطل)، 3 (ماتل)، أو 4 (موريتل)';
    }
    
    return 'رقم الهاتف غير صحيح';
  }
}
