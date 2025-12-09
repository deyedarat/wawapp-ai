import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/admin_app_router.dart';
import 'core/theme/app_theme.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);

    return MaterialApp.router(
      title: 'WawApp Admin - لوحة إدارة واو أب',
      debugShowCheckedModeBanner: false,
      
      // Theme
      theme: AdminAppTheme.lightTheme,
      darkTheme: AdminAppTheme.darkTheme,
      themeMode: ThemeMode.light, // TODO: Implement theme switching
      
      // Localization
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'), // Arabic
        Locale('fr'), // French
      ],
      
      // Routing
      routerConfig: router,
    );
  }
}
