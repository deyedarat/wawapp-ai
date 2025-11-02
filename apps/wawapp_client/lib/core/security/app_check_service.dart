import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckService {
  static Future<void> initialize() async {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode 
        ? AndroidProvider.debug 
        : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode 
        ? AppleProvider.debug 
        : AppleProvider.deviceCheck,
    );
  }

  static Future<String?> getToken() async {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('App Check token error: $e');
      }
      return null;
    }
  }

  static Future<void> setTokenAutoRefreshEnabled(bool enabled) async {
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(enabled);
  }
}