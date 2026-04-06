import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/analytics_service.dart';
import 'features/update/force_update_provider.dart';
import 'features/update/force_update_screen.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';

/// Top-level background message handler for data-only FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final type = message.data['notificationType'] ?? message.data['type'];

  // Show full-screen intent notification for order-related data-only messages
  if (type == 'new_order' ||
      type == 'new_order_nearby' ||
      type == 'unassigned_order_reminder') {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final orderId = message.data['orderId'] ?? '';
    final pickupLabel = message.data['pickupLabel'] ?? 'موقع الاستلام';
    final dropoffLabel = message.data['dropoffLabel'] ?? 'الوجهة';
    final channelId = type == 'unassigned_order_reminder'
        ? 'unassigned_orders'
        : 'new_orders';

    await plugin.show(
      orderId.hashCode,
      message.data['title'] ?? 'طلب جديد قريب منك',
      '$pickupLabel → $dropoffLabel',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == 'new_orders' ? 'طلبات جديدة' : 'تذكير بطلبات متاحة',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

void main() async {
  // Run app initialization in error zone to catch all errors
  runZonedGuarded<Future<void>>(() async {
    if (kDebugMode) {
      print('🟢 WawApp Driver starting...');
    }

    WidgetsFlutterBinding.ensureInitialized();

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

    if (kDebugMode) {
      print('✅ Firebase initialized, Crashlytics ready');
    }

    // Register background message handler for data-only FCM messages
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
  } on FirebaseException catch (e) {
    if (kDebugMode) {
      print('⚠️ Failed to enable Firestore offline persistence: $e');
      print('   App will continue without offline support.');
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

    // FCM will be initialized after authentication in auth_gate.dart

    // Defer analytics to background (non-blocking)
    Future.microtask(() {
      AnalyticsService.instance.setUserType();
    });

    // Initialize notification service immediately after first frame
    // Must not delay — onMessage listener needs to be registered ASAP
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NotificationService().initialize();
      }
    });
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
