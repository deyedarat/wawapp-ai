import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @title.
  ///
  /// In ar, this message translates to:
  /// **'واو أب - السائق'**
  String get title;

  /// No description provided for @online.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get offline;

  /// No description provided for @nearby_requests.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات القريبة'**
  String get nearby_requests;

  /// No description provided for @wallet.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get wallet;

  /// No description provided for @total_earnings.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الأرباح'**
  String get total_earnings;

  /// No description provided for @today_earnings.
  ///
  /// In ar, this message translates to:
  /// **'أرباح اليوم'**
  String get today_earnings;

  /// No description provided for @accept.
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get accept;

  /// No description provided for @sign_in_with_phone.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول بالهاتف'**
  String get sign_in_with_phone;

  /// No description provided for @pin_label.
  ///
  /// In ar, this message translates to:
  /// **'الرمز السري (PIN)'**
  String get pin_label;

  /// No description provided for @set_pin.
  ///
  /// In ar, this message translates to:
  /// **'إعداد الرمز السري'**
  String get set_pin;

  /// No description provided for @confirm_pin.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الرمز السري'**
  String get confirm_pin;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @pin_error_length.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن يتكون الرمز من 4 أرقام'**
  String get pin_error_length;

  /// No description provided for @pin_error_weak.
  ///
  /// In ar, this message translates to:
  /// **'الرمز ضعيف جداً. تجنب الأرقام المتكررة أو المتسلسلة'**
  String get pin_error_weak;

  /// No description provided for @pin_error_mismatch.
  ///
  /// In ar, this message translates to:
  /// **'الرموز غير متطابقة'**
  String get pin_error_mismatch;

  /// No description provided for @pin_saved_success.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الرمز السري بنجاح'**
  String get pin_saved_success;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profile;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @no_profile_yet.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم إعداد الملف الشخصي بعد'**
  String get no_profile_yet;

  /// No description provided for @create_profile.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الملف الشخصي'**
  String get create_profile;

  /// No description provided for @personal_info.
  ///
  /// In ar, this message translates to:
  /// **'المعلومات الشخصية'**
  String get personal_info;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get name;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف'**
  String get phone;

  /// No description provided for @city.
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get city;

  /// No description provided for @not_specified.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get not_specified;

  /// No description provided for @region.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة'**
  String get region;

  /// No description provided for @vehicle_info.
  ///
  /// In ar, this message translates to:
  /// **'معلومات السيارة'**
  String get vehicle_info;

  /// No description provided for @vehicle_type.
  ///
  /// In ar, this message translates to:
  /// **'نوع السيارة'**
  String get vehicle_type;

  /// No description provided for @plate_number.
  ///
  /// In ar, this message translates to:
  /// **'رقم اللوحة'**
  String get plate_number;

  /// No description provided for @color.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get color;

  /// No description provided for @statistics.
  ///
  /// In ar, this message translates to:
  /// **'الإحصائيات'**
  String get statistics;

  /// No description provided for @rating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم'**
  String get rating;

  /// No description provided for @total_trips.
  ///
  /// In ar, this message translates to:
  /// **'عدد الرحلات'**
  String get total_trips;

  /// No description provided for @verification_status.
  ///
  /// In ar, this message translates to:
  /// **'حالة التحقق'**
  String get verification_status;

  /// No description provided for @verified.
  ///
  /// In ar, this message translates to:
  /// **'تم التحقق'**
  String get verified;

  /// No description provided for @not_verified.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم التحقق'**
  String get not_verified;

  /// No description provided for @security.
  ///
  /// In ar, this message translates to:
  /// **'الأمان'**
  String get security;

  /// No description provided for @change_pin.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الرمز السري'**
  String get change_pin;

  /// No description provided for @change_pin_subtitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيير رمز PIN الخاص بك'**
  String get change_pin_subtitle;

  /// No description provided for @change_pin_title.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الرمز السري'**
  String get change_pin_title;

  /// No description provided for @change_pin_message.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إرسال رمز التحقق OTP إلى رقم هاتفك لتأكيد هويتك قبل تغيير الرمز السري.'**
  String get change_pin_message;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @continueButton.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueButton;

  /// No description provided for @phone_not_available.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف غير متوفر. يرجى تسجيل الدخول مرة أخرى'**
  String get phone_not_available;

  /// No description provided for @otp_send_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إرسال OTP'**
  String get otp_send_failed;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @logout_title.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout_title;

  /// No description provided for @logout_confirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من تسجيل الخروج؟'**
  String get logout_confirm;

  /// No description provided for @terms_of_service.
  ///
  /// In ar, this message translates to:
  /// **'شروط الخدمة'**
  String get terms_of_service;

  /// No description provided for @privacy_policy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacy_policy;

  /// No description provided for @by_continuing_you_agree.
  ///
  /// In ar, this message translates to:
  /// **'بالمتابعة، أنت توافق على'**
  String get by_continuing_you_agree;

  /// No description provided for @and.
  ///
  /// In ar, this message translates to:
  /// **'و'**
  String get and;

  /// No description provided for @delete_account.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get delete_account;

  /// No description provided for @delete_account_title.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get delete_account_title;

  /// No description provided for @delete_account_warning.
  ///
  /// In ar, this message translates to:
  /// **'هذا الإجراء لا يمكن التراجع عنه. سيتم حذف جميع بياناتك بشكل دائم.'**
  String get delete_account_warning;

  /// No description provided for @delete_account_confirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف حسابك؟'**
  String get delete_account_confirm;

  /// No description provided for @account_deleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الحساب بنجاح'**
  String get account_deleted;

  /// No description provided for @error_delete_account.
  ///
  /// In ar, this message translates to:
  /// **'فشل حذف الحساب. يرجى المحاولة مرة أخرى'**
  String get error_delete_account;

  /// No description provided for @deleting_account.
  ///
  /// In ar, this message translates to:
  /// **'جاري حذف الحساب...'**
  String get deleting_account;

  /// No description provided for @type_delete_to_confirm.
  ///
  /// In ar, this message translates to:
  /// **'اكتب \'حذف\' للتأكيد'**
  String get type_delete_to_confirm;

  /// No description provided for @check_phone.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الهاتف'**
  String get check_phone;

  /// No description provided for @create_account.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get create_account;

  /// No description provided for @new_user_create_account.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم جديد - إنشاء حساب'**
  String get new_user_create_account;

  /// No description provided for @existing_user_enter_pin.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم حالي - أدخل الرمز السري (PIN)'**
  String get existing_user_enter_pin;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get login;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
