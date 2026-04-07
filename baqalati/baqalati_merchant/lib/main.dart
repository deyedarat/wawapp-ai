import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/products_provider.dart';
import 'screens/auth/merchant_login_screen.dart';
import 'screens/dashboard/merchant_dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Initialize Firebase
  // await Firebase.initializeApp();
  runApp(const BaqalatiMerchantApp());
}

class BaqalatiMerchantApp extends StatelessWidget {
  const BaqalatiMerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'بقالتي للتجار',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme.copyWith(
              appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(
                backgroundColor: AppTheme.primaryGreenDark,
              ),
            ),
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
                  return const MerchantDashboardScreen();
                }
                return const MerchantLoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
