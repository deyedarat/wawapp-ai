import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_skill/flutter_skill.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/router/navigator.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/trip_start_reminder_screen.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/acceptance_lock_manager.dart';
import 'services/analytics_service.dart';
import 'services/notification_dedup_service.dart';
import 'services/notification_helper.dart';
import 'services/notification_logger.dart';
import 'services/orders_service.dart';
import 'features/update/force_update_provider.dart';
import 'features/update/force_update_screen.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'services/fcm_token_manager.dart';
import 'services/battery_optimization_manager.dart';
import 'services/notification_health_monitor.dart';
import 'services/missed_notification_recovery.dart';

/// REMOVED: Dart background handler is no longer used.
/// Background FCM messages are handled by MyFirebaseMessagingService.kt (Native Kotlin).
/// This ensures proper fullScreenIntent support when app is killed or screen is locked.
///
/// Performance monitoring and logging for background messages will be added
/// to MyFirebaseMessagingService.kt in the future if needed.

void main() async {
  runZonedGuarded<Future<void>>(() async {
    if (kDebugMode) {
      print('🟢 WawApp Driver starting...');
    }

    WidgetsFlutterBinding.ensureInitialized();

    if (kDebugMode) FlutterSkillBinding.ensureInitialized();

    // Initialize Firebase with retry logic to handle race conditions
    // Firebase may auto-initialize in parallel on Android
    bool firebaseInitialized = false;
    for (int attempt = 0; attempt < 3 && !firebaseInitialized; attempt++) {
      try {
        if (Firebase.apps.isEmpty) {
          if (kDebugMode && attempt == 0) {
            print('🔵 Initializing Firebase...');
          }
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          firebaseInitialized = true;
          if (kDebugMode) {
            print('✅ Firebase initialized successfully');
          }
        } else {
          firebaseInitialized = true;
          if (kDebugMode) {
            print('✅ Firebase already initialized');
          }
        }
      } on FirebaseException catch (e) {
        if (e.code == 'duplicate-app') {
          // Race condition: Firebase was initialized between isEmpty check and initializeApp
          firebaseInitialized = true;
          if (kDebugMode) {
            print('✅ Firebase already initialized (race condition resolved)');
          }
        } else {
          // Different error, wait and retry
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
        }
      }
    }

    // Initialize Crashlytics
    await _initializeCrashlytics();

    // Enable Firestore offline persistence
    await _enableFirestoreOfflinePersistence();

    // Initialize connectivity monitoring
    await ConnectivityService().initialize();

    // Initialize FCM token manager (handles token refresh automatically)
    await FcmTokenManager().initialize();

    // Check battery optimization status (but don't request yet - do it after login)
    await BatteryOptimizationManager().isExemptFromBatteryOptimization();

    if (kDebugMode) {
      print(
          '✅ Firebase initialized, Crashlytics ready, FCM token manager started');
    }

    // Register a no-op background handler to prevent Flutter FCM plugin from
    // auto-displaying notifications. Native MyFirebaseMessagingService.kt handles
    // the actual notification display (FullScreenNotificationActivity).
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) {
    // Catch errors that occur outside of Flutter framework
    if (kDebugMode) {
      print('❌ Uncaught error: $error');
      print('Stack trace: $stack');
    }
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

// ---------------------------------------------------------------------------
// REMOVED: Duplicate FCM tap handlers (_setupNotificationHandlers,
// _processTapData, _navigateForNotification, _pendingNotificationData).
//
// All FCM tap routing (onMessageOpenedApp, getInitialMessage) is now handled
// exclusively by NotificationService to eliminate race conditions.
// See: services/notification_service.dart
// ---------------------------------------------------------------------------

// No-op background handler — suppresses Flutter plugin auto-notification.
// Actual handling is done by MyFirebaseMessagingService.kt (Native).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty. Native Kotlin handler does the work.
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
        print('❌ Platform error: $error');
        print('Stack: $stack');
      }
      crashlytics.recordError(error, stack, fatal: true);
      return true; // Mark as handled
    };

    if (kDebugMode) {
      print('✅ Crashlytics error handlers configured');
    }
  } catch (e) {
    // If Crashlytics fails to initialize (e.g., missing config), log but don't crash
    if (kDebugMode) {
      print('⚠️ Crashlytics initialization failed: $e');
      print('   App will continue without crash reporting.');
    }
  }
}

/// Enable Firestore offline persistence for better connectivity handling
Future<void> _enableFirestoreOfflinePersistence() async {
  try {
    // Enable offline persistence with unlimited cache size
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    if (kDebugMode) {
      print('✅ Firestore offline persistence enabled');
    }
  } on Object catch (e) {
    // Firestore may already be started (e.g. by background isolate or implicit read).
    // Settings cannot be changed after start — safe to continue without them.
    if (kDebugMode) {
      print('Firestore settings skipped: $e');
    }
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // FCM will be initialized after authentication in auth_gate.dart

    // Defer analytics to background (non-blocking)
    Future.microtask(() {
      AnalyticsService.instance.setUserType();
    });

    // Initialize notification service immediately after first frame
    // Must not delay — onMessage listener needs to be registered ASAP
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await NotificationService().initialize();

        // Initialize persistent dedup service
        final prefs = await SharedPreferences.getInstance();
        NotificationService().initDedup(NotificationDedupService(prefs));

        // PATCH-04 (RC-15): Process the cold-start FCM message AFTER dedup is
        // injected. Previously this ran inside initialize() before initDedup(),
        // making replay protection unavailable on cold start.
        await NotificationService().processInitialMessage();

        // Initialize notification health monitoring
        final monitor = NotificationHealthMonitor();
        if (await monitor.needsHealthCheck()) {
          final report = await monitor.checkHealth();
          await monitor.logHealthToFirestore(report);

          // Auto-repair if health is critical
          if (report.isCritical) {
            if (kDebugMode) {
              debugPrint(
                  '[Main] 🔴 Critical notification health, running auto-repair');
            }
            await monitor.autoRepair();
          }
        }

        // Start missed notification recovery (only after user is authenticated)
        // Will be triggered from auth_gate after successful login
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // EC1: Reconcile active order on resume (handles lost accept responses)
      OrdersService.reconcileActiveOrder().then((orderId) {
        if (orderId != null && mounted) {
          // Driver has an active order they may not know about — navigate
          final ctx = context;
          if (ctx.mounted) {
            GoRouter.of(ctx).go('/active-order');
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(forceUpdateProvider);
    final router = ref.watch(appRouterProvider);
    NotificationService().updateContext(context);

    return updateState.when(
      loading: () => _buildApp(router),
      error: (_, __) => _buildApp(router),
      data: (state) {
        if (state.mustUpdate) {
          return MaterialApp(
            title: 'WawApp Driver',
            theme: AppTheme.lightTheme,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('fr')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: ForceUpdateScreen(
              downloadUrl: state.downloadUrl,
              latestVersion: state.latestVersion,
              message: state.message,
            ),
          );
        }
        return _buildApp(router);
      },
    );
  }

  Widget _buildApp(GoRouter router) {
    return MaterialApp.router(
      title: 'WawApp Driver',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('fr'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
