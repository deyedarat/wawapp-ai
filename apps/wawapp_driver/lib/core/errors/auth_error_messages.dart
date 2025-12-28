/**
 * FIX #2: Enhanced Authentication Error Messages
 * 
 * Provides clear, actionable Arabic error messages for drivers
 * during the authentication flow to improve multi-device experience.
 * 
 * Author: WawApp Development Team (Critical Fix)
 * Last Updated: 2025-12-28
 */

/// Authentication error messages in Arabic
class AuthErrorMessages {
  static const String pinIncorrect = 'الرقم السري غير صحيح. حاول مرة أخرى';
  static const String accountNotFound = 'الحساب غير موجود. تأكد من رقم الهاتف';
  static const String invalidOtp = 'رمز التحقق غير صحيح. أعد المحاولة';
  static const String otpExpired = 'انتهت صلاحية رمز التحقق. أرسل رمزاً جديداً';
  static const String tooManyRequests = 'عدد كبير جداً من المحاولات. جرب لاحقاً';
  static const String networkError = 'خطأ في الاتصال. تحقق من اتصال الإنترنت';
  static const String unknownError = 'حدث خطأ غير متوقع. حاول مرة أخرى';
  static const String pinCreationFailed = 'فشل إنشاء الرقم السري. حاول مرة أخرى';
  static const String sessionExpired = 'انتهت الجلسة. سجّل دخولك مرة أخرى';
  
  /// Get user-friendly error message from Firebase error
  static String getErrorMessage(dynamic error) {
    if (error == null) return unknownError;
    
    final errorString = error.toString().toLowerCase();
    
    // OTP-related errors
    if (errorString.contains('invalid-verification-code') ||
        errorString.contains('invalid-code')) {
      return invalidOtp;
    }
    
    if (errorString.contains('session-expired') ||
        errorString.contains('code-expired')) {
      return otpExpired;
    }
    
    if (errorString.contains('too-many-requests') ||
        errorString.contains('quota-exceeded')) {
      return tooManyRequests;
    }
    
    // Network-related errors
    if (errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection')) {
      return networkError;
    }
    
    // PIN-related errors
    if (errorString.contains('pin') && errorString.contains('invalid')) {
      return pinIncorrect;
    }
    
    // Account-related errors
    if (errorString.contains('user-not-found') ||
        errorString.contains('account-not-found')) {
      return accountNotFound;
    }
    
    return unknownError;
  }
}
