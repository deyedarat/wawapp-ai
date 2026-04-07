import 'package:flutter/material.dart';
import 'app_ar.dart';
import 'app_fr.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String> get _localizedStrings {
    switch (locale.languageCode) {
      case 'ar':
        return arStrings;
      case 'fr':
        return frStrings;
      default:
        return arStrings;
    }
  }

  String tr(String key) {
    return _localizedStrings[key] ?? key;
  }

  bool get isArabic => locale.languageCode == 'ar';
  bool get isFrench => locale.languageCode == 'fr';
  String get languageCode => locale.languageCode;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ar', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
