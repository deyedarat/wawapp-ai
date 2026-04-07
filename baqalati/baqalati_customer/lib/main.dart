import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/orders_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Initialize Firebase
  // await Firebase.initializeApp();
  runApp(const BaqalatiCustomerApp());
}

class BaqalatiCustomerApp extends StatelessWidget {
  const BaqalatiCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'بقالتي',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            locale: localeProvider.locale,
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
            home: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                if (authProvider.isLoggedIn) {
                  return const HomeScreen();
                }
                return const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
