// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get title => 'WawApp - Chauffeur';

  @override
  String get online => 'En ligne';

  @override
  String get offline => 'Hors ligne';

  @override
  String get nearby_requests => 'Demandes à proximité';

  @override
  String get wallet => 'Portefeuille';

  @override
  String get total_earnings => 'Gains totaux';

  @override
  String get today_earnings => 'Gains du jour';

  @override
  String get accept => 'Accepter';
}
