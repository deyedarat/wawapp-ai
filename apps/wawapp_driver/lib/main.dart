import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'services/notification_helper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final notificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  print('🟢 APP STARTED');
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Suppress reCAPTCHA error in debug mode
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    await FirebaseAuth.instance
        .setSettings(appVerificationDisabledForTesting: true);
  }

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
