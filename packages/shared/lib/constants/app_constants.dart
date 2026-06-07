/// Application-wide constants.
class AppConstants {
  AppConstants._();

  /// App name in Arabic.
  static const String appNameAr = 'واو آب';

  /// App name in French.
  static const String appNameFr = 'WawApp';

  /// Mauritania country code.
  static const String countryCode = '+222';

  /// Mauritania phone number length (without country code).
  static const int phoneNumberLength = 8;

  /// Currency used in Mauritania (MRU - Ouguiya).
  static const String currency = 'MRU';

  /// Currency symbol.
  static const String currencySymbol = 'أوقية';

  /// Currency symbol in French.
  static const String currencySymbolFr = 'MRU';

  /// Default language.
  static const String defaultLanguage = 'ar';

  /// Supported languages.
  static const List<String> supportedLanguages = ['ar', 'fr'];

  /// Maximum rating value.
  static const int maxRating = 5;

  /// Default estimated completion hours.
  static const int defaultCompletionHours = 24;

  /// OTP timeout in seconds.
  static const int otpTimeoutSeconds = 60;

  /// OTP length.
  static const int otpLength = 6;

  /// Pagination page size.
  static const int pageSize = 20;
}
