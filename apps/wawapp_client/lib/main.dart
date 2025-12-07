import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/build_info/build_info.dart';
import 'core/build_info/build_info_banner.dart';
import 'core/location/location_bootstrap.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';

Future<void> _setupDebugAuth() async {
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      debugPrint('🔧 Setting up debug authentication...');
      // Sign in anonymously for testing
      await auth.signInAnonymously();
      debugPrint('✅ Debug auth complete: ${auth.currentUser?.uid}');
    }
  } catch (e) {
    debugPrint('Debug auth error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 WawApp initializing...');

  await BuildInfoProvider.initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Debug authentication bypass for testing
    if (kDebugMode) {
      await _setupDebugAuth();
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  debugPrint('📍 Ensuring location ready...');
  await ensureLocationReady();

  debugPrint('✅ WawApp initialization complete');
  runApp(const ProviderScope(child: MyApp()));
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
      builder: (context, child) =>
          BuildInfoBanner(child: child ?? const SizedBox()),
    );
  }
}
