import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'waw_log.dart';

class CrashlyticsObserver {
  static Future<void> initialize() async {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    WawLog.setCrashlyticsInstance(FirebaseCrashlytics.instance);

    if (kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    }
  }

  /// Set user context (call after auth)
  static void setUserContext(String userId, String role) {
    FirebaseCrashlytics.instance.setUserIdentifier(userId);
    FirebaseCrashlytics.instance.setCustomKey('user_id', userId);
    FirebaseCrashlytics.instance.setCustomKey('role', role);
  }

  /// Set current route context
  static void setRoute(String route, String screen) {
    FirebaseCrashlytics.instance.setCustomKey('current_route', route);
    FirebaseCrashlytics.instance.setCustomKey('screen', screen);
  }

  /// Log breadcrumb with standard format
  static void logBreadcrumb(String name, {String? screen, String? route, String? action, Map<String, String>? extra}) {
    final parts = <String>[name];
    if (screen != null) parts.add('screen:$screen');
    if (route != null) parts.add('route:$route');
    if (action != null) parts.add('action:$action');
    if (extra != null) {
      for (final entry in extra.entries) {
        parts.add('${entry.key}:${entry.value}');
      }
    }

    FirebaseCrashlytics.instance.log('[BREADCRUMB] ${parts.join(' | ')}');
  }

  /// Log navigation attempt with context
  static void logNavigation({
    required String action,
    required String from,
    String? to,
    required bool canPop,
    required bool mounted,
  }) {
    FirebaseCrashlytics.instance.setCustomKey('nav_action', action);
    FirebaseCrashlytics.instance.setCustomKey('nav_from', from);
    if (to != null) FirebaseCrashlytics.instance.setCustomKey('nav_to', to);
    FirebaseCrashlytics.instance.setCustomKey('can_pop', canPop.toString());
    FirebaseCrashlytics.instance.setCustomKey('mounted', mounted.toString());

    logBreadcrumb(
      'NAV_$action',
      extra: {'from': from, if (to != null) 'to': to, 'canPop': canPop.toString(), 'mounted': mounted.toString()},
    );
  }

  /// Log map operation with context
  static void logMapOperation({
    required String action,
    required bool mapReady,
    required bool controllerReady,
    String? screen,
  }) {
    FirebaseCrashlytics.instance.setCustomKey('map_ready', mapReady.toString());
    FirebaseCrashlytics.instance.setCustomKey('controller_ready', controllerReady.toString());
    FirebaseCrashlytics.instance.setCustomKey('camera_action', action);

    logBreadcrumb(
      'MAP_$action',
      screen: screen,
      extra: {'mapReady': mapReady.toString(), 'controllerReady': controllerReady.toString()},
    );
  }

  static void testCrash() {
    throw Exception('Test crash from WawApp');
  }
}
