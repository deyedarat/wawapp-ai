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

  @override
  String get sign_in_with_phone => 'تسجيل الدخول بالهاتف';

  @override
  String get pin_label => 'الرمز السري (PIN)';

  @override
  String get set_pin => 'إعداد الرمز السري';

  @override
  String get confirm_pin => 'تأكيد الرمز السري';

  @override
  String get save => 'حفظ';

  @override
  String get pin_error_length => 'يجب أن يتكون الرمز من 4 أرقام';

  @override
  String get pin_error_weak =>
      'الرمز ضعيف جداً. تجنب الأرقام المتكررة أو المتسلسلة';

  @override
  String get pin_error_mismatch => 'الرموز غير متطابقة';

  @override
  String get pin_saved_success => 'تم حفظ الرمز السري بنجاح';
}
