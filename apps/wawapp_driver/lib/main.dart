import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart';
import 'package:auth_shared/auth_shared.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';

// Phase 2: Observability Services (Global Instances)
final _lifecycleObserver = AppLifecycleObserver();
final _networkMonitor = NetworkMonitor();
final _breadcrumbs = BreadcrumbService();
final _crashlytics = CrashlyticsKeysManager();
TokenRefreshManager? _tokenRefreshManager;

/// Phase 2: Initialize all observability services
Future<void> _initializePhase2Observability() async {
  print('🔍 Phase 2: Initializing observability...');

  await CrashlyticsObserver.initialize();
  print('✅ Crashlytics initialized');

  final packageInfo = await PackageInfo.fromPlatform();
  final platform = Platform.isAndroid ? 'android' : 'ios';
  
  await _crashlytics.setSessionContext(
    appVersion: packageInfo.version,
    platform: platform,
    networkType: NetworkTypeValues.wifi,
  );
  print('✅ Session context set: v${packageInfo.version} on $platform');

  await _networkMonitor.initialize();
  print('✅ Network monitor started');

  _lifecycleObserver.initialize();
  print('✅ Lifecycle observer registered');

  _breadcrumbs.add(action: 'app_launched', screen: 'system');
  print('✅ Phase 2 observability fully initialized');
}

/// Phase 2: Check for interrupted auth verification (TC-01)
Future<void> _checkInterruptedVerification() async {
  final interrupted = await AuthPersistenceManager.getInterruptedVerification();
  if (interrupted != null) {
    _breadcrumbs.add(
      action: BreadcrumbActions.authVerificationInterrupted,
      screen: 'auth',
      metadata: {
        'phone': interrupted.phoneE164,
        'age_minutes': DateTime.now().difference(interrupted.timestamp).inMinutes,
      },
    );
    print('⚠️ Detected interrupted verification for ${interrupted.phoneE164}');
  }
}

/// Phase 2: Check for active order after app kill (TC-07, TC-14)
Future<void> _checkActiveOrderAfterKill() async {
  final activeOrder = await AuthPersistenceManager.getActiveOrderBeforeLogout();
  if (activeOrder != null) {
    _breadcrumbs.add(
      action: BreadcrumbActions.appKilledWithActiveOrder,
      screen: 'system',
      metadata: {
        'orderId': activeOrder.orderId,
        'status': activeOrder.status,
      },
    );

    await _crashlytics.setActiveOrderContext(
      activeOrderId: activeOrder.orderId,
      activeOrderStatus: activeOrder.status,
    );

    print('⚠️ Detected active order after app kill: ${activeOrder.orderId} (${activeOrder.status})');
  }
}

/// Phase 2: Start token refresh monitoring (TC-02)
void _startTokenRefreshMonitoring() {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) {
    _tokenRefreshManager = TokenRefreshManager(
      firebaseAuth: auth,
      onRefreshEvent: (event) {
        switch (event.status) {
          case TokenRefreshStatus.attemptStarted:
            _breadcrumbs.add(action: BreadcrumbActions.tokenRefreshAttempt, screen: 'system');
            break;
          case TokenRefreshStatus.success:
            _breadcrumbs.add(action: BreadcrumbActions.tokenRefreshSuccess, screen: 'system');
            break;
          case TokenRefreshStatus.failed:
            _breadcrumbs.add(
              action: BreadcrumbActions.tokenRefreshFailed,
              screen: 'system',
              metadata: {'error': event.errorMessage},
            );
            _crashlytics.recordNonFatal(
              failurePoint: FailurePoints.tokenRefresh,
              message: 'Token refresh failed: ${event.errorMessage}',
              additionalData: {'error': event.errorMessage},
            );
            break;
          case TokenRefreshStatus.checkFailed:
            break;
        }
      },
    );
    _tokenRefreshManager!.startMonitoring();
    print('✅ Token refresh monitoring started');
  }
}

void main() async {
  print('🟢 WawApp Driver STARTED');
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Phase 2: Initialize observability FIRST
  await _initializePhase2Observability();

  // Phase 2: Check for interrupted verification (TC-01)
  await _checkInterruptedVerification();

  // Phase 2: Check for active order after app kill (TC-07, TC-14)
  await _checkActiveOrderAfterKill();

  // Suppress reCAPTCHA error in debug mode
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    await FirebaseAuth.instance
        .setSettings(appVerificationDisabledForTesting: true);
  }

  // Phase 2: Start token refresh monitoring (TC-02)
  _startTokenRefreshMonitoring();

  print('✅ WawApp Driver initialization complete');
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
    // FCM will be initialized after authentication in auth_gate.dart
    AnalyticsService.instance.setUserType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize(context);
    });

    // Phase 2: Listen to auth state changes to update Crashlytics user context
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _crashlytics.setUserContext(
          userId: user.uid,
          userRole: UserRoleValues.driver,
          authState: AuthStateValues.authenticated,
        );
        _breadcrumbs.add(
          action: BreadcrumbActions.loginSuccess,
          screen: 'auth',
          userId: user.uid,
        );
      } else {
        _crashlytics.setUserContext(
          userId: null,
          userRole: UserRoleValues.driver,
          authState: AuthStateValues.anonymous,
        );
      }
    });
  }

  @override
  void dispose() {
    // Phase 2: Cleanup
    _lifecycleObserver.dispose();
    _networkMonitor.dispose();
    _tokenRefreshManager?.stopMonitoring();
    super.dispose();
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
