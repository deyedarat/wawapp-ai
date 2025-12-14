import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get configuration
  final config = AppConfigFactory.current;
  
  // Log environment information
  _logEnvironmentInfo(config);
  
  // CRITICAL: Safety check for production builds
  if (!config.useStrictAuth && kReleaseMode) {
    throw Exception(
      '🚨 CRITICAL SECURITY ERROR 🚨\n'
      'Dev auth bypass is enabled in release mode!\n'
      'This is a severe security violation.\n'
      'Build MUST use: flutter build web --release --dart-define=ENVIRONMENT=prod'
    );
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: AdminApp(),
    ),
  );
}

/// Log environment information to console
void _logEnvironmentInfo(AppConfig config) {
  // Print banner
  print('\n${'=' * 70}');
  print('🚀 WAWAPP ADMIN PANEL');
  print('=' * 70);
  print('📍 Environment: ${config.environment.toUpperCase()}');
  print('🔒 Strict Auth: ${config.useStrictAuth}');
  print('🐛 Debug Logging: ${config.enableDebugLogging}');
  print('🔧 Dev Tools: ${config.showDevTools}');
  print('🏢 Firebase Project: ${config.firebaseProjectId}');
  print('=' * 70);
  
  // CRITICAL: Show prominent warning if dev mode
  if (!config.useStrictAuth) {
    print('\n');
    print('⚠️' * 30);
    print('⚠️  WARNING: DEVELOPMENT MODE ACTIVE');
    print('⚠️' * 30);
    print('⚠️');
    print('⚠️  DEV AUTH BYPASS IS ENABLED!');
    print('⚠️');
    print('⚠️  Any authenticated user can access the admin panel.');
    print('⚠️  This should NEVER be used in production!');
    print('⚠️');
    print('⚠️  Security Risks:');
    print('⚠️  • No role-based access control');
    print('⚠️  • Financial data exposed');
    print('⚠️  • Audit trail compromised');
    print('⚠️');
    print('⚠️  To fix: Build with --dart-define=ENVIRONMENT=prod');
    print('⚠️');
    print('⚠️' * 30);
    print('\n');
  } else {
    print('✅ Production mode: Strict authentication enforced');
    print('✅ Admin access requires isAdmin custom claim');
  }
  
  print('\n');
}
