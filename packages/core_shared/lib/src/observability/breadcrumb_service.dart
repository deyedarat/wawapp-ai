import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Minimal breadcrumb service for Crashlytics observability
class BreadcrumbService {
  static FirebaseCrashlytics? _crashlytics;

  static void initialize(FirebaseCrashlytics crashlytics) {
    _crashlytics = crashlytics;
  }

  /// Log a breadcrumb to Crashlytics
  /// Each breadcrumb includes: timestamp, userId, screen, action
  static Future<void> log({
    required String action,
    String? userId,
    String? screen,
    Map<String, String>? extra,
  }) async {
    if (_crashlytics == null) return;

    final timestamp = DateTime.now().toIso8601String();
    final breadcrumb = StringBuffer('[$timestamp] $action');
    
    if (userId != null) breadcrumb.write(' | userId=$userId');
    if (screen != null) breadcrumb.write(' | screen=$screen');
    if (extra != null && extra.isNotEmpty) {
      extra.forEach((key, value) {
        breadcrumb.write(' | $key=$value');
      });
    }

    await _crashlytics?.log(breadcrumb.toString());
  }

  // --- Required 6 Breadcrumbs ---

  static Future<void> appLaunched({String? userId}) async {
    await log(action: 'app_launched', userId: userId);
  }

  static Future<void> loginAttempt({required String phone, String? screen}) async {
    await log(action: 'login_attempt', screen: screen, extra: {'phone': phone});
  }

  static Future<void> loginSuccess({required String userId, String? screen}) async {
    await log(action: 'login_success', userId: userId, screen: screen);
  }

  static Future<void> loginFailed({String? userId, String? screen, String? reason}) async {
    await log(action: 'login_failed', userId: userId, screen: screen, extra: reason != null ? {'reason': reason} : null);
  }

  static Future<void> orderCreateAttempt({required String userId, String? screen}) async {
    await log(action: 'order_create_attempt', userId: userId, screen: screen);
  }

  static Future<void> orderCreateFailed({required String userId, String? screen, String? reason}) async {
    await log(action: 'order_create_failed', userId: userId, screen: screen, extra: reason != null ? {'reason': reason} : null);
  }

  static Future<void> appBackgrounded({String? userId}) async {
    await log(action: 'app_backgrounded', userId: userId);
  }
}
