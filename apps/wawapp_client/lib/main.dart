import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/build_info/build_info.dart';
import 'core/build_info/build_info_banner.dart';
import 'core/location/location_bootstrap.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'services/notification_helper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final notificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 WawApp initializing...');

  await BuildInfoProvider.initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await notificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        final payload = jsonEncode(message.data);
        notificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails('default', 'Default'),
          ),
          payload: payload,
        );
      }
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  debugPrint('📍 Ensuring location ready...');
  await ensureLocationReady();

  debugPrint('✅ WawApp initialization complete');
  runApp(const ProviderScope(child: MyApp()));
}

void _onNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload != null) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final route = NotificationHelper.getRouteFromNotification(
        type: data['type'],
        role: data['role'],
      );
      if (route != null && navigatorKey.currentContext != null) {
        navigatorKey.currentContext!.go(route);
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }
}

void _handleMessage(RemoteMessage message) {
  final data = message.data;
  final route = NotificationHelper.getRouteFromNotification(
    type: data['type'],
    role: data['role'],
  );
  if (route != null && navigatorKey.currentContext != null) {
    navigatorKey.currentContext!.go(route);
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
    FcmService().initialize();
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  @override
  Widget build(BuildContext context) {
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
