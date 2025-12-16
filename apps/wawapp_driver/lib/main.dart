import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:core_shared/core_shared.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';

void main() async {
  print('🟢 APP STARTED');
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Crashlytics observability
    await CrashlyticsObserver.initialize();
    final crashlytics = FirebaseCrashlytics.instance;
    BreadcrumbService.initialize(crashlytics);
    CrashlyticsKeys.initialize(crashlytics);

    // Set initial Crashlytics context
    final packageInfo = await PackageInfo.fromPlatform();
    await CrashlyticsKeys.setAppVersion(packageInfo.version);
    await CrashlyticsKeys.setPlatform();
    await CrashlyticsKeys.setAuthState('initial');
    await CrashlyticsKeys.setNetworkType('unknown');
    await CrashlyticsKeys.setUserRole('driver');

    // Log app launch breadcrumb
    await BreadcrumbService.appLaunched();

    // Suppress reCAPTCHA error in debug mode
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      await FirebaseAuth.instance
          .setSettings(appVerificationDisabledForTesting: true);
    }
  } catch (e, stack) {
    print('Firebase initialization error: $e');
    WawLog.e('main', 'Firebase initialization failed', e, stack);
  }

  runApp(const ProviderScope(child: MyApp()));
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
    AnalyticsService.instance.setUserType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App backgrounded
      final userId = FirebaseAuth.instance.currentUser?.uid;
      BreadcrumbService.appBackgrounded(userId: userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    NotificationService().updateContext(context);

    return MaterialApp.router(
      title: 'WawApp Driver',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
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
