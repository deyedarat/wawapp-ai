import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'config/app_config.dart';

void main() async {
  // Run app initialization in error zone to catch all errors
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Get configuration
    final config = AppConfigFactory.current;

    // Log environment information (debug only)
    if (kDebugMode) {
      _logEnvironmentInfo(config);
    }

    // CRITICAL: Safety check for production builds
    if (!config.useStrictAuth && kReleaseMode) {
      throw Exception('🚨 CRITICAL SECURITY ERROR 🚨\n'
          'Dev auth bypass is enabled in release mode!\n'
          'This is a severe security violation.\n'
          'Build MUST use: flutter build web --release --dart-define=ENVIRONMENT=prod');
    }

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Crashlytics (works on Android/iOS, gracefully fails on web)
    await _initializeCrashlytics();

    if (kDebugMode) {
      print('✅ Firebase & Crashlytics initialized');
    }

    runApp(
      const ProviderScope(
        child: AdminApp(),
      ),
    );
  }, (error, stack) {
    // Catch errors that occur outside of Flutter framework
    if (kDebugMode) {
      print('❌ Uncaught error: $error');
      print('Stack trace: $stack');
    }
    // Attempt to record to Crashlytics (may fail on web, that's ok)
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (e) {
      // Crashlytics not available on web, ignore
      if (kDebugMode) {
        print('⚠️ Could not record to Crashlytics: $e');
      }
    }
  });
}

/// Initialize Firebase Crashlytics with proper error handlers
/// Note: Crashlytics is not supported on web, will gracefully fail
Future<void> _initializeCrashlytics() async {
  try {
    final crashlytics = FirebaseCrashlytics.instance;

    // Pass all uncaught Flutter framework errors to Crashlytics
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        // In debug mode, print to console for developer visibility
        FlutterError.presentError(details);
      }
      // Always record to Crashlytics (even in debug for testing)
      try {
        crashlytics.recordFlutterFatalError(details);
      } catch (e) {
        // Crashlytics may not be available (e.g., on web)
        if (kDebugMode) {
          print('⚠️ Crashlytics not available: $e');
        }
      }
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        print('❌ Platform error: $error');
        print('Stack: $stack');
      }
      try {
        crashlytics.recordError(error, stack, fatal: true);
      } catch (e) {
        // Crashlytics may not be available (e.g., on web)
      }
      return true; // Mark as handled
    };

    if (kDebugMode) {
      print('✅ Crashlytics error handlers configured');
    }
  } catch (e) {
    // If Crashlytics fails to initialize (e.g., on web or missing config), log but don't crash
    if (kDebugMode) {
      print('⚠️ Crashlytics initialization failed: $e');
      print('   App will continue without crash reporting (normal for web).');
    }
  }
}

/// Log environment information to console
void _logEnvironmentInfo(AppConfig config) {
  // Print banner
  print('\n${'=' * 70}');
  print('🚀 WAWAPP ADMIN PANEL');
  print('=' * 70);
  print('📍 Environment: ${config.environment.toUpperCase()}');
  print('🔒 Strict Auth: ${config.useStrictAuth}');
  print('🐛 Debug Logging: ${config.enableDebugLogging}');
  print('🔧 Dev Tools: ${config.showDevTools}');
  print('🏢 Firebase Project: ${config.firebaseProjectId}');
  print('=' * 70);

  // CRITICAL: Show prominent warning if dev mode
  if (!config.useStrictAuth) {
    print('\n');
    print('⚠️' * 30);
    print('⚠️  WARNING: DEVELOPMENT MODE ACTIVE');
    print('⚠️' * 30);
    print('⚠️');
    print('⚠️  DEV AUTH BYPASS IS ENABLED!');
    print('⚠️');
    print('⚠️  Any authenticated user can access the admin panel.');
    print('⚠️  This should NEVER be used in production!');
    print('⚠️');
    print('⚠️  Security Risks:');
    print('⚠️  • No role-based access control');
    print('⚠️  • Financial data exposed');
    print('⚠️  • Audit trail compromised');
    print('⚠️');
    print('⚠️  To fix: Build with --dart-define=ENVIRONMENT=prod');
    print('⚠️');
    print('⚠️' * 30);
    print('\n');
  } else {
    print('✅ Production mode: Strict authentication enforced');
    print('✅ Admin access requires isAdmin custom claim');
  }

  print('\n');
}
