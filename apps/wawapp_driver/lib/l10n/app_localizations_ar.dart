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
