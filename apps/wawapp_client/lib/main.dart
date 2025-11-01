import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/build_info/build_info.dart';
import 'core/build_info/build_info_banner.dart';
import 'core/location/location_bootstrap.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 WawApp initializing...');

  await BuildInfoProvider.initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint('🔑 FCM Token: $fcmToken');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // 2) Prepare location service & permission early (non-blocking).
  debugPrint('📍 Ensuring location ready...');
  await ensureLocationReady();

  debugPrint('✅ WawApp initialization complete');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

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
      routerConfig: router,
      builder: (context, child) =>
          BuildInfoBanner(child: child ?? const SizedBox()),
    );
  }
}
