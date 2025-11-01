// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get title => 'واو أب - السائق';

  @override
  String get online => 'متصل';

  @override
  String get offline => 'غير متصل';

  @override
  String get nearby_requests => 'الطلبات القريبة';

  @override
  String get wallet => 'المحفظة';

  @override
  String get total_earnings => 'إجمالي الأرباح';

  @override
  String get today_earnings => 'أرباح اليوم';

  @override
  String get accept => 'قبول';
}
