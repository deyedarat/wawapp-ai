import 'dart:async';
import 'dart:ui';

import 'package:core_shared/core_shared.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/build_info/build_info.dart';
import 'core/build_info/build_info_banner.dart';
import 'core/firebase_boot.dart';
import 'core/location/location_bootstrap.dart';
import 'core/pricing/pricing_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/config/config_gate.dart';
import 'l10n/app_localizations.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';

void main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (kDebugMode) {
        debugPrint('🚀 WawApp Client initializing...');
      }

      await BuildInfoProvider.initialize();

      // Step 1: Safe Firebase initialization (handles duplicate-app gracefully)
      try {
        await FirebaseBoot.ensure();
        if (kDebugMode) {
          debugPrint('✅ Firebase initialized');
        }
      } catch (e) {
        debugPrint('❌ Firebase initialization error: $e');
      }

      // Step 2: App Check (must run AFTER Firebase, in its own try-catch)
      // CRITICAL: PlayIntegrity ONLY works for apps from Google Play Store
      // Solution: Always use PlayIntegrity (works on Play Store, gracefully fails locally)
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        );
        if (kDebugMode) {
          debugPrint('✅ Firebase App Check activated with Play Integrity');
        }
      } catch (e) {
        // Expected to fail on local ADB installs - this is NORMAL
        // On Play Store, this will succeed
        if (kDebugMode) {
          debugPrint('⚠️ App Check activation failed (expected for ADB installs): $e');
        }
      }

      // Step 3: Crashlytics (in its own try-catch)
      try {
        await _initializeCrashlytics();
        await CrashlyticsObserver.initialize();
        if (kDebugMode) {
          debugPrint('✅ Crashlytics initialized');
        }
      } catch (e) {
        debugPrint('⚠️ Crashlytics initialization failed: $e');
      }

      if (kDebugMode) {
        debugPrint('📍 Ensuring location ready...');
      }
      await ensureLocationReady();

      // Step 4: Load pricing config from Firestore (non-blocking on failure)
      try {
        await initPricingConfig();
        if (kDebugMode) {
          debugPrint('✅ Pricing config loaded');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Pricing config load failed, using defaults: $e');
        }
      }

      if (kDebugMode) {
        debugPrint('✅ WawApp Client initialization complete');
      }

      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      // Catch errors that occur outside of Flutter framework
      if (kDebugMode) {
        debugPrint('❌ Uncaught error: $error');
        debugPrint('Stack trace: $stack');
      }
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

/// Initialize Firebase Crashlytics with proper error handlers
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
      crashlytics.recordFlutterFatalError(details);
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('❌ Platform error: $error');
        debugPrint('Stack: $stack');
      }
      crashlytics.recordError(error, stack, fatal: true);
      return true; // Mark as handled
    };

    if (kDebugMode) {
      debugPrint('✅ Crashlytics error handlers configured');
    }
  } catch (e) {
    // If Crashlytics fails to initialize (e.g., missing config), log but don't crash
    if (kDebugMode) {
      debugPrint('⚠️ Crashlytics initialization failed: $e');
      debugPrint('   App will continue without crash reporting.');
    }
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // FCM will be initialized after authentication in phone_pin_login_screen.dart
    AnalyticsService.instance.setUserType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    // Keep pricing config synced with Firestore in real-time
    ref.watch(pricingConfigProvider);
    NotificationService().updateContext(context);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      title: 'WawApp Client',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        return ConfigGate(child: BuildInfoBanner(child: child ?? const SizedBox()));
      },
    );
  }
}
