import 'package:flutter/material.dart';
import 'l10n.dart';

/// Provides localized strings for the application.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Whether the current locale is Arabic.
  bool get isArabic => locale.languageCode == 'ar';

  /// Whether the current locale is French.
  bool get isFrench => locale.languageCode == 'fr';

  /// Gets a localized string by key.
  String get(String key) {
    final translations = isArabic ? L10n.ar : L10n.fr;
    return translations[key] ?? key;
  }

  // ==================== COMMON ====================
  String get appName => get('app_name');
  String get loading => get('loading');
  String get error => get('error');
  String get retry => get('retry');
  String get cancel => get('cancel');
  String get confirm => get('confirm');
  String get save => get('save');
  String get delete => get('delete');
  String get edit => get('edit');
  String get search => get('search');
  String get noData => get('no_data');
  String get success => get('success');
  String get ok => get('ok');
  String get yes => get('yes');
  String get no => get('no');
  String get close => get('close');
  String get back => get('back');
  String get next => get('next');
  String get done => get('done');
  String get settings => get('settings');
  String get language => get('language');
  String get arabic => get('arabic');
  String get french => get('french');
  String get logout => get('logout');
  String get logoutConfirm => get('logout_confirm');

  // ==================== AUTH ====================
  String get login => get('login');
  String get register => get('register');
  String get phoneNumber => get('phone_number');
  String get enterPhone => get('enter_phone');
  String get enterOtp => get('enter_otp');
  String get otpSent => get('otp_sent');
  String get verifyOtp => get('verify_otp');
  String get resendOtp => get('resend_otp');
  String get enterName => get('enter_name');
  String get fullName => get('full_name');
  String get welcomeBack => get('welcome_back');
  String get createAccount => get('create_account');
  String get invalidPhone => get('invalid_phone');
  String get invalidOtp => get('invalid_otp');

  // ==================== ORDERS ====================
  String get orders => get('orders');
  String get newOrder => get('new_order');
  String get createOrder => get('create_order');
  String get orderDetails => get('order_details');
  String get orderHistory => get('order_history');
  String get activeOrders => get('active_orders');
  String get pendingOrders => get('pending_orders');
  String get readyOrders => get('ready_orders');
  String get deliveredOrders => get('delivered_orders');
  String get orderStatus => get('order_status');
  String get orderCreated => get('order_created');
  String get orderReady => get('order_ready');
  String get orderDelivered => get('order_delivered');
  String get estimatedTime => get('estimated_time');
  String get totalPrice => get('total_price');
  String get items => get('items');
  String get addItem => get('add_item');
  String get removeItem => get('remove_item');
  String get quantity => get('quantity');
  String get price => get('price');
  String get notes => get('notes');
  String get discount => get('discount');
  String get selectCustomer => get('select_customer');
  String get noOrders => get('no_orders');
  String get markAsReady => get('mark_as_ready');
  String get markAsDelivered => get('mark_as_delivered');
  String get markAsWashing => get('mark_as_washing');
  String get cancelOrder => get('cancel_order');

  // ==================== STATUS ====================
  String get statusReceived => get('status_received');
  String get statusWashing => get('status_washing');
  String get statusReady => get('status_ready');
  String get statusDelivered => get('status_delivered');
  String get statusCancelled => get('status_cancelled');

  // ==================== CUSTOMERS ====================
  String get customers => get('customers');
  String get customerList => get('customer_list');
  String get addCustomer => get('add_customer');
  String get customerDetails => get('customer_details');
  String get searchByPhone => get('search_by_phone');
  String get noCustomers => get('no_customers');

  // ==================== DASHBOARD ====================
  String get dashboard => get('dashboard');
  String get todayOrders => get('today_orders');
  String get revenue => get('revenue');
  String get dailyRevenue => get('daily_revenue');
  String get weeklyRevenue => get('weekly_revenue');
  String get monthlyRevenue => get('monthly_revenue');
  String get totalOrders => get('total_orders');

  // ==================== NOTIFICATIONS ====================
  String get notifications => get('notifications');
  String get orderReceivedNotification => get('order_received_notification');
  String get orderReadyNotification => get('order_ready_notification');
  String get noNotifications => get('no_notifications');

  // ==================== RATING ====================
  String get rateService => get('rate_service');
  String get ratingSubmitted => get('rating_submitted');
  String get addComment => get('add_comment');
  String get thankYou => get('thank_you');

  // ==================== ITEMS ====================
  String get shirt => get('shirt');
  String get pants => get('pants');
  String get thobe => get('thobe');
  String get dress => get('dress');
  String get jacket => get('jacket');
  String get blanket => get('blanket');
  String get bedsheet => get('bedsheet');
  String get towel => get('towel');
  String get curtain => get('curtain');
  String get abaya => get('abaya');
  String get melhfa => get('melhfa');
  String get boubou => get('boubou');
  String get underwear => get('underwear');
  String get socks => get('socks');
  String get other => get('other');
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
