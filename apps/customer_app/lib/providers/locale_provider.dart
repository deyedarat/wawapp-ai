import 'package:flutter/material.dart';

/// Provider for managing the customer app's locale (Arabic/French).
class CustomerLocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void toggleLocale() {
    _locale = isArabic ? const Locale('fr') : const Locale('ar');
    notifyListeners();
  }
}
