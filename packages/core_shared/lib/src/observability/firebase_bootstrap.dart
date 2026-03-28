import 'package:firebase_core/firebase_core.dart';
import 'waw_log.dart';
import 'crashlytics_observer.dart';

/// Centralized Firebase initialization helper
/// Ensures Firebase is initialized exactly once per isolate
class FirebaseBootstrap {
  static bool _initialized = false;

  /// Initialize Firebase and Crashlytics
  /// Safe to call multiple times - will only initialize once
  static Future<void> initialize(FirebaseOptions options) async {
    if (_initialized) {
      WawLog.d('FirebaseBootstrap', 'Already initialized, skipping');
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
        WawLog.d('FirebaseBootstrap', 'Firebase initialized');
      }

      await CrashlyticsObserver.initialize();
      _initialized = true;
      WawLog.d('FirebaseBootstrap', '✅ Firebase & Crashlytics ready');
    } catch (e, stack) {
      WawLog.e('FirebaseBootstrap', 'Initialization failed', e, stack);
      rethrow;
    }
  }

  /// For background isolates (FCM handlers)
  /// Only initializes Firebase, not Crashlytics
  static Future<void> initializeBackground(FirebaseOptions options) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
      WawLog.d('FirebaseBootstrap', 'Background isolate initialized');
    }
  }
}
