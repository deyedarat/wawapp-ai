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

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'واو أب'**
  String get appTitle;

  /// No description provided for @pickup.
  ///
  /// In ar, this message translates to:
  /// **'موقع الاستلام'**
  String get pickup;

  /// No description provided for @dropoff.
  ///
  /// In ar, this message translates to:
  /// **'موقع التسليم'**
  String get dropoff;

  /// No description provided for @get_quote.
  ///
  /// In ar, this message translates to:
  /// **'احسب السعر'**
  String get get_quote;

  /// No description provided for @request_now.
  ///
  /// In ar, this message translates to:
  /// **'اطلب الآن'**
  String get request_now;

  /// No description provided for @track.
  ///
  /// In ar, this message translates to:
  /// **'تتبع'**
  String get track;

  /// No description provided for @currency.
  ///
  /// In ar, this message translates to:
  /// **'أوقية'**
  String get currency;

  /// No description provided for @estimated_price.
  ///
  /// In ar, this message translates to:
  /// **'السعر المقدر'**
  String get estimated_price;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get done;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get error;

  /// No description provided for @success.
  ///
  /// In ar, this message translates to:
  /// **'نجح'**
  String get success;

  /// No description provided for @greeting.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً'**
  String get greeting;

  /// No description provided for @welcome_back.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بعودتك'**
  String get welcome_back;

  /// No description provided for @start_new_shipment.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ شحنة جديدة'**
  String get start_new_shipment;

  /// No description provided for @select_pickup_dropoff.
  ///
  /// In ar, this message translates to:
  /// **'حدد مواقع الالتقاط والتسليم'**
  String get select_pickup_dropoff;

  /// No description provided for @begin_shipment.
  ///
  /// In ar, this message translates to:
  /// **'بدء شحنة'**
  String get begin_shipment;

  /// No description provided for @selected_category.
  ///
  /// In ar, this message translates to:
  /// **'الفئة المختارة'**
  String get selected_category;

  /// No description provided for @quick_select_category.
  ///
  /// In ar, this message translates to:
  /// **'اختر فئة بسرعة'**
  String get quick_select_category;

  /// No description provided for @current_shipment.
  ///
  /// In ar, this message translates to:
  /// **'الشحنة الحالية'**
  String get current_shipment;

  /// No description provided for @no_active_shipments.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد شحنات جارية حالياً'**
  String get no_active_shipments;

  /// No description provided for @track_shipment.
  ///
  /// In ar, this message translates to:
  /// **'تتبع الشحنة'**
  String get track_shipment;

  /// No description provided for @past_shipments.
  ///
  /// In ar, this message translates to:
  /// **'شحناتك السابقة'**
  String get past_shipments;

  /// No description provided for @view_history.
  ///
  /// In ar, this message translates to:
  /// **'عرض السجل'**
  String get view_history;

  /// No description provided for @safe_reliable_delivery.
  ///
  /// In ar, this message translates to:
  /// **'نقوم بنقل الحمولة داخل نواكشوط بأمان واحتراف'**
  String get safe_reliable_delivery;

  /// No description provided for @driver_assigned.
  ///
  /// In ar, this message translates to:
  /// **'تم تعيين سائق'**
  String get driver_assigned;

  /// No description provided for @shipment_status.
  ///
  /// In ar, this message translates to:
  /// **'حالة الشحنة'**
  String get shipment_status;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profile;

  /// No description provided for @about_app.
  ///
  /// In ar, this message translates to:
  /// **'حول التطبيق'**
  String get about_app;

  /// No description provided for @price_breakdown.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل السعر'**
  String get price_breakdown;

  /// No description provided for @base_fare.
  ///
  /// In ar, this message translates to:
  /// **'أجرة الأساس'**
  String get base_fare;

  /// No description provided for @per_km.
  ///
  /// In ar, this message translates to:
  /// **'لكل كم'**
  String get per_km;

  /// No description provided for @distance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة'**
  String get distance;

  /// No description provided for @total.
  ///
  /// In ar, this message translates to:
  /// **'المجموع'**
  String get total;

  /// No description provided for @shipment_type_multiplier.
  ///
  /// In ar, this message translates to:
  /// **'مُضاعف نوع الشحنة'**
  String get shipment_type_multiplier;

  /// No description provided for @final_price.
  ///
  /// In ar, this message translates to:
  /// **'السعر النهائي'**
  String get final_price;

  /// No description provided for @estimated_time.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المقدر'**
  String get estimated_time;

  /// No description provided for @base_price.
  ///
  /// In ar, this message translates to:
  /// **'السعر الأساسي'**
  String get base_price;

  /// No description provided for @distance_cost.
  ///
  /// In ar, this message translates to:
  /// **'تكلفة المسافة'**
  String get distance_cost;

  /// No description provided for @shipment_multiplier.
  ///
  /// In ar, this message translates to:
  /// **'مضاعف الشحنة'**
  String get shipment_multiplier;

  /// No description provided for @minute.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get minute;

  /// No description provided for @km.
  ///
  /// In ar, this message translates to:
  /// **'كم'**
  String get km;

  /// No description provided for @error_create_order.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إنشاء الطلب. يرجى المحاولة مرة أخرى'**
  String get error_create_order;

  /// No description provided for @confirm_shipment.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الشحنة'**
  String get confirm_shipment;

  /// No description provided for @requesting_driver.
  ///
  /// In ar, this message translates to:
  /// **'جاري البحث عن سائق...'**
  String get requesting_driver;

  /// No description provided for @finding_nearby_drivers.
  ///
  /// In ar, this message translates to:
  /// **'البحث عن السائقين القريبين'**
  String get finding_nearby_drivers;

  /// No description provided for @price_summary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص السعر'**
  String get price_summary;

  /// No description provided for @from.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get from;

  /// No description provided for @to.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get to;

  /// No description provided for @shipment_details.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الشحنة'**
  String get shipment_details;

  /// No description provided for @order_tracking.
  ///
  /// In ar, this message translates to:
  /// **'تتبع الطلب'**
  String get order_tracking;

  /// No description provided for @shipment_timeline.
  ///
  /// In ar, this message translates to:
  /// **'الجدول الزمني للشحنة'**
  String get shipment_timeline;

  /// No description provided for @order_placed.
  ///
  /// In ar, this message translates to:
  /// **'تم تقديم الطلب'**
  String get order_placed;

  /// No description provided for @driver_accepted.
  ///
  /// In ar, this message translates to:
  /// **'قبل السائق'**
  String get driver_accepted;

  /// No description provided for @driver_arrived.
  ///
  /// In ar, this message translates to:
  /// **'وصل السائق'**
  String get driver_arrived;

  /// No description provided for @picked_up.
  ///
  /// In ar, this message translates to:
  /// **'تم الاستلام'**
  String get picked_up;

  /// No description provided for @in_transit.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق'**
  String get in_transit;

  /// No description provided for @delivered.
  ///
  /// In ar, this message translates to:
  /// **'تم التسليم'**
  String get delivered;

  /// No description provided for @cancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get cancelled;

  /// No description provided for @driver_info.
  ///
  /// In ar, this message translates to:
  /// **'معلومات السائق'**
  String get driver_info;

  /// No description provided for @driver_name.
  ///
  /// In ar, this message translates to:
  /// **'اسم السائق'**
  String get driver_name;

  /// No description provided for @vehicle_info.
  ///
  /// In ar, this message translates to:
  /// **'معلومات المركبة'**
  String get vehicle_info;

  /// No description provided for @phone_number.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phone_number;

  /// No description provided for @call_driver.
  ///
  /// In ar, this message translates to:
  /// **'اتصل بالسائق'**
  String get call_driver;

  /// No description provided for @arriving_in.
  ///
  /// In ar, this message translates to:
  /// **'يصل خلال'**
  String get arriving_in;

  /// No description provided for @minutes.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get minutes;

  /// No description provided for @order_status.
  ///
  /// In ar, this message translates to:
  /// **'حالة الطلب'**
  String get order_status;

  /// No description provided for @waiting_for_pickup.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار الاستلام'**
  String get waiting_for_pickup;

  /// No description provided for @on_the_way.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق'**
  String get on_the_way;

  /// No description provided for @order_details.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get order_details;

  /// No description provided for @saved_locations.
  ///
  /// In ar, this message translates to:
  /// **'المواقع المحفوظة'**
  String get saved_locations;

  /// No description provided for @add_location.
  ///
  /// In ar, this message translates to:
  /// **'إضافة موقع'**
  String get add_location;

  /// No description provided for @edit_location.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الموقع'**
  String get edit_location;

  /// No description provided for @delete_location.
  ///
  /// In ar, this message translates to:
  /// **'حذف الموقع'**
  String get delete_location;

  /// No description provided for @location_name.
  ///
  /// In ar, this message translates to:
  /// **'اسم الموقع'**
  String get location_name;

  /// No description provided for @location_address.
  ///
  /// In ar, this message translates to:
  /// **'عنوان الموقع'**
  String get location_address;

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'المنزل'**
  String get home;

  /// No description provided for @work.
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get work;

  /// No description provided for @other.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get other;

  /// No description provided for @no_saved_locations.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواقع محفوظة'**
  String get no_saved_locations;

  /// No description provided for @add_your_first_location.
  ///
  /// In ar, this message translates to:
  /// **'أضف موقعك الأول لتسهيل الاستخدام'**
  String get add_your_first_location;

  /// No description provided for @location_saved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الموقع'**
  String get location_saved;

  /// No description provided for @location_deleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الموقع'**
  String get location_deleted;

  /// No description provided for @confirm_delete.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحذف'**
  String get confirm_delete;

  /// No description provided for @delete_location_message.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف هذا الموقع؟'**
  String get delete_location_message;

  /// No description provided for @no_saved_locations_message.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على + لإضافة موقع جديد'**
  String get no_saved_locations_message;

  /// No description provided for @delete_location_confirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف \"{name}\"؟'**
  String delete_location_confirm(String name);

  /// No description provided for @location_deleted_success.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الموقع بنجاح'**
  String get location_deleted_success;

  /// No description provided for @error_delete_location.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في حذف الموقع'**
  String get error_delete_location;

  /// No description provided for @order_history.
  ///
  /// In ar, this message translates to:
  /// **'سجل الطلبات'**
  String get order_history;

  /// No description provided for @no_past_orders.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات سابقة'**
  String get no_past_orders;

  /// No description provided for @start_your_first_shipment.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ شحنتك الأولى الآن'**
  String get start_your_first_shipment;

  /// No description provided for @completed_on.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل في'**
  String get completed_on;

  /// No description provided for @view_details.
  ///
  /// In ar, this message translates to:
  /// **'عرض التفاصيل'**
  String get view_details;

  /// No description provided for @reorder.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الطلب'**
  String get reorder;

  /// No description provided for @trip_completed.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل التوصيل'**
  String get trip_completed;

  /// No description provided for @thank_you.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لاستخدامك واو أب'**
  String get thank_you;

  /// No description provided for @delivery_successful.
  ///
  /// In ar, this message translates to:
  /// **'تم التوصيل بنجاح'**
  String get delivery_successful;

  /// No description provided for @rate_your_experience.
  ///
  /// In ar, this message translates to:
  /// **'قيّم تجربتك'**
  String get rate_your_experience;

  /// No description provided for @rate_driver.
  ///
  /// In ar, this message translates to:
  /// **'قيّم السائق'**
  String get rate_driver;

  /// No description provided for @share_feedback.
  ///
  /// In ar, this message translates to:
  /// **'شارك رأيك'**
  String get share_feedback;

  /// No description provided for @write_feedback.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رأيك (اختياري)'**
  String get write_feedback;

  /// No description provided for @submit_rating.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get submit_rating;

  /// No description provided for @skip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get skip;

  /// No description provided for @excellent.
  ///
  /// In ar, this message translates to:
  /// **'ممتاز'**
  String get excellent;

  /// No description provided for @good.
  ///
  /// In ar, this message translates to:
  /// **'جيد'**
  String get good;

  /// No description provided for @average.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get average;

  /// No description provided for @poor.
  ///
  /// In ar, this message translates to:
  /// **'ضعيف'**
  String get poor;

  /// No description provided for @very_poor.
  ///
  /// In ar, this message translates to:
  /// **'ضعيف جداً'**
  String get very_poor;

  /// No description provided for @rating_submitted.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال التقييم'**
  String get rating_submitted;

  /// No description provided for @delivery_summary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص التوصيل'**
  String get delivery_summary;

  /// No description provided for @trip_completed_success.
  ///
  /// In ar, this message translates to:
  /// **'تم إكمال الرحلة بنجاح'**
  String get trip_completed_success;

  /// No description provided for @trip_details.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرحلة'**
  String get trip_details;

  /// No description provided for @total_cost.
  ///
  /// In ar, this message translates to:
  /// **'التكلفة الكلية'**
  String get total_cost;

  /// No description provided for @completed_at.
  ///
  /// In ar, this message translates to:
  /// **'وقت الإنجاز'**
  String get completed_at;

  /// No description provided for @rate_driver_subtitle.
  ///
  /// In ar, this message translates to:
  /// **'ساعدنا في تحسين الخدمة بتقييمك'**
  String get rate_driver_subtitle;

  /// No description provided for @rating_thank_you.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لتقييمك!'**
  String get rating_thank_you;

  /// No description provided for @error_submit_rating.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال التقييم، حاول مرة أخرى'**
  String get error_submit_rating;

  /// No description provided for @order_not_found.
  ///
  /// In ar, this message translates to:
  /// **'الطلب غير موجود'**
  String get order_not_found;

  /// No description provided for @my_profile.
  ///
  /// In ar, this message translates to:
  /// **'ملفي الشخصي'**
  String get my_profile;

  /// No description provided for @edit_profile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get edit_profile;

  /// No description provided for @full_name.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get full_name;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phone;

  /// No description provided for @account_info.
  ///
  /// In ar, this message translates to:
  /// **'معلومات الحساب'**
  String get account_info;

  /// No description provided for @preferences.
  ///
  /// In ar, this message translates to:
  /// **'التفضيلات'**
  String get preferences;

  /// No description provided for @language_settings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات اللغة'**
  String get language_settings;

  /// No description provided for @notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// No description provided for @notification_settings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الإشعارات'**
  String get notification_settings;

  /// No description provided for @privacy.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get terms;

  /// No description provided for @help.
  ///
  /// In ar, this message translates to:
  /// **'المساعدة'**
  String get help;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @logout_confirmation.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من تسجيل الخروج؟'**
  String get logout_confirmation;

  /// No description provided for @profile_updated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الملف الشخصي'**
  String get profile_updated;

  /// No description provided for @version.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get version;

  /// No description provided for @no_profile.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم إعداد الملف الشخصي بعد'**
  String get no_profile;

  /// No description provided for @no_profile_message.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ ملفك الشخصي للحصول على تجربة أفضل'**
  String get no_profile_message;

  /// No description provided for @setup_profile.
  ///
  /// In ar, this message translates to:
  /// **'إعداد الملف الشخصي'**
  String get setup_profile;

  /// No description provided for @personal_info.
  ///
  /// In ar, this message translates to:
  /// **'المعلومات الشخصية'**
  String get personal_info;

  /// No description provided for @quick_actions.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة'**
  String get quick_actions;

  /// No description provided for @total_trips.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الرحلات'**
  String get total_trips;

  /// No description provided for @rating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم'**
  String get rating;

  /// No description provided for @saved_locations_subtitle.
  ///
  /// In ar, this message translates to:
  /// **'إدارة المواقع المفضلة لديك'**
  String get saved_locations_subtitle;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @error_loading_data.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في تحميل البيانات'**
  String get error_loading_data;

  /// No description provided for @language_ar.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get language_ar;

  /// No description provided for @language_fr.
  ///
  /// In ar, this message translates to:
  /// **'الفرنسية'**
  String get language_fr;

  /// No description provided for @language_en.
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزية'**
  String get language_en;

  /// No description provided for @app_settings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات التطبيق'**
  String get app_settings;

  /// No description provided for @general.
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get general;

  /// No description provided for @theme.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get theme;

  /// No description provided for @light_mode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع النهاري'**
  String get light_mode;

  /// No description provided for @dark_mode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الليلي'**
  String get dark_mode;

  /// No description provided for @system_default.
  ///
  /// In ar, this message translates to:
  /// **'افتراضي النظام'**
  String get system_default;

  /// No description provided for @push_notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات الفورية'**
  String get push_notifications;

  /// No description provided for @order_updates.
  ///
  /// In ar, this message translates to:
  /// **'تحديثات الطلبات'**
  String get order_updates;

  /// No description provided for @promotional.
  ///
  /// In ar, this message translates to:
  /// **'العروض الترويجية'**
  String get promotional;

  /// No description provided for @sound.
  ///
  /// In ar, this message translates to:
  /// **'الصوت'**
  String get sound;

  /// No description provided for @vibration.
  ///
  /// In ar, this message translates to:
  /// **'الاهتزاز'**
  String get vibration;

  /// No description provided for @legal.
  ///
  /// In ar, this message translates to:
  /// **'قانوني'**
  String get legal;

  /// No description provided for @privacy_policy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacy_policy;

  /// No description provided for @about.
  ///
  /// In ar, this message translates to:
  /// **'حول'**
  String get about;

  /// No description provided for @app_version.
  ///
  /// In ar, this message translates to:
  /// **'نسخة التطبيق'**
  String get app_version;

  /// No description provided for @contact_support.
  ///
  /// In ar, this message translates to:
  /// **'اتصل بالدعم'**
  String get contact_support;

  /// No description provided for @app_description.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق لتوصيل البضائع داخل نواكشوط بأمان وسرعة'**
  String get app_description;

  /// No description provided for @version_info.
  ///
  /// In ar, this message translates to:
  /// **'معلومات الإصدار'**
  String get version_info;

  /// No description provided for @branch.
  ///
  /// In ar, this message translates to:
  /// **'الفرع'**
  String get branch;

  /// No description provided for @commit.
  ///
  /// In ar, this message translates to:
  /// **'الكوميت'**
  String get commit;

  /// No description provided for @flavor.
  ///
  /// In ar, this message translates to:
  /// **'النكهة'**
  String get flavor;

  /// No description provided for @flutter_version.
  ///
  /// In ar, this message translates to:
  /// **'إصدار فلاتر'**
  String get flutter_version;

  /// No description provided for @features.
  ///
  /// In ar, this message translates to:
  /// **'المميزات'**
  String get features;

  /// No description provided for @feature_realtime_tracking.
  ///
  /// In ar, this message translates to:
  /// **'تتبع الشحنات في الوقت الفعلي'**
  String get feature_realtime_tracking;

  /// No description provided for @feature_cargo_types.
  ///
  /// In ar, this message translates to:
  /// **'6 فئات متخصصة للبضائع'**
  String get feature_cargo_types;

  /// No description provided for @feature_instant_quotes.
  ///
  /// In ar, this message translates to:
  /// **'أسعار فورية ودقيقة'**
  String get feature_instant_quotes;

  /// No description provided for @feature_multilingual.
  ///
  /// In ar, this message translates to:
  /// **'دعم اللغة العربية والفرنسية'**
  String get feature_multilingual;

  /// No description provided for @copyright.
  ///
  /// In ar, this message translates to:
  /// **'© 2025 واو أب. جميع الحقوق محفوظة'**
  String get copyright;

  /// No description provided for @choose_shipment_type.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الحمولة'**
  String get choose_shipment_type;

  /// No description provided for @cargo_delivery_service.
  ///
  /// In ar, this message translates to:
  /// **'خدمة توصيل البضائع'**
  String get cargo_delivery_service;

  /// No description provided for @cargo_delivery_subtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الحمولة لنوفر لك أفضل خدمة'**
  String get cargo_delivery_subtitle;

  /// No description provided for @select_cargo_type.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الشحنة'**
  String get select_cargo_type;

  /// No description provided for @notifications_title.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications_title;

  /// No description provided for @no_notifications.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات'**
  String get no_notifications;

  /// No description provided for @mark_all_read.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الكل كمقروء'**
  String get mark_all_read;

  /// No description provided for @clear_all.
  ///
  /// In ar, this message translates to:
  /// **'مسح الكل'**
  String get clear_all;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @earlier.
  ///
  /// In ar, this message translates to:
  /// **'سابقاً'**
  String get earlier;

  /// No description provided for @newLabel.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get newLabel;

  /// No description provided for @error_occurred.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get error_occurred;

  /// No description provided for @try_again.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get try_again;

  /// No description provided for @network_error.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في الاتصال'**
  String get network_error;

  /// No description provided for @no_internet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت'**
  String get no_internet;

  /// No description provided for @something_went_wrong.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ ما'**
  String get something_went_wrong;

  /// No description provided for @please_wait.
  ///
  /// In ar, this message translates to:
  /// **'يرجى الانتظار'**
  String get please_wait;
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
