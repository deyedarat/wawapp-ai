import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  String get languageCode => _locale.languageCode;

  void setLocale(Locale locale) {
    if (!['ar', 'fr'].contains(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
  }

  void toggleLocale() {
    _locale = _locale.languageCode == 'ar'
        ? const Locale('fr')
        : const Locale('ar');
    notifyListeners();
  }
}
