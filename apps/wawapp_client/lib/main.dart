import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart';
import 'package:auth_shared/auth_shared.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/build_info/build_info.dart';
import 'core/build_info/build_info_banner.dart';
import 'core/location/location_bootstrap.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';

// Phase 2: Observability Services (Global Instances)
final _lifecycleObserver = AppLifecycleObserver();
final _networkMonitor = NetworkMonitor();
final _breadcrumbs = BreadcrumbService();
final _crashlytics = CrashlyticsKeysManager();
TokenRefreshManager? _tokenRefreshManager;

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

/// Phase 2: Initialize all observability services
Future<void> _initializePhase2Observability() async {
  debugPrint('🔍 Phase 2: Initializing observability...');

  // 1. Initialize Crashlytics
  await CrashlyticsObserver.initialize();
  debugPrint('✅ Crashlytics initialized');

  // 2. Get app info for session context
  final packageInfo = await PackageInfo.fromPlatform();
  final platform = Platform.isAndroid ? 'android' : 'ios';
  
  await _crashlytics.setSessionContext(
    appVersion: packageInfo.version,
    platform: platform,
    networkType: NetworkTypeValues.wifi, // Will be updated by NetworkMonitor
  );
  debugPrint('✅ Session context set: v${packageInfo.version} on $platform');

  // 3. Initialize NetworkMonitor
  await _networkMonitor.initialize();
  debugPrint('✅ Network monitor started');

  // 4. Initialize AppLifecycleObserver
  _lifecycleObserver.initialize();
  debugPrint('✅ Lifecycle observer registered');

  // 5. Log app startup breadcrumb
  _breadcrumbs.add(
    action: 'app_launched',
    screen: 'system',
  );

  debugPrint('✅ Phase 2 observability fully initialized');
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
    
    debugPrint('⚠️ Detected interrupted verification for ${interrupted.phoneE164}');
    debugPrint('   Age: ${DateTime.now().difference(interrupted.timestamp).inMinutes} minutes');
  }
}

/// Phase 2: Check for active order after app kill (TC-06, TC-14)
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

    debugPrint('⚠️ Detected active order after app kill: ${activeOrder.orderId} (${activeOrder.status})');
  }
}

/// Phase 2: Start token refresh monitoring (TC-02)
void _startTokenRefreshMonitoring() {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) {
    _tokenRefreshManager = TokenRefreshManager(
      firebaseAuth: auth,
      onRefreshEvent: (event) {
        // Log token refresh events to breadcrumbs
        switch (event.status) {
          case TokenRefreshStatus.attemptStarted:
            _breadcrumbs.add(
              action: BreadcrumbActions.tokenRefreshAttempt,
              screen: 'system',
            );
            break;
          case TokenRefreshStatus.success:
            _breadcrumbs.add(
              action: BreadcrumbActions.tokenRefreshSuccess,
              screen: 'system',
            );
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
            // Non-critical, just log
            break;
        }
      },
    );
    _tokenRefreshManager!.startMonitoring();
    debugPrint('✅ Token refresh monitoring started');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 WawApp Client initializing...');

  await BuildInfoProvider.initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Phase 2: Initialize observability FIRST (before any other operations)
    await _initializePhase2Observability();

    // Phase 2: Check for interrupted verification session (TC-01)
    await _checkInterruptedVerification();

    // Phase 2: Check for active order after app kill (TC-06, TC-14)
    await _checkActiveOrderAfterKill();
    
    // Debug authentication bypass for testing
    if (kDebugMode) {
      await _setupDebugAuth();
    }

    // Phase 2: Start token refresh monitoring if user is authenticated (TC-02)
    _startTokenRefreshMonitoring();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    
    // Phase 2: Log critical initialization failure
    _breadcrumbs.add(
      action: 'firebase_init_failed',
      screen: 'system',
      metadata: {'error': e.toString()},
    );
  }

  debugPrint('📍 Ensuring location ready...');
  await ensureLocationReady();

  debugPrint('✅ WawApp Client initialization complete');
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

    // Phase 2: Listen to auth state changes to update Crashlytics user context
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _crashlytics.setUserContext(
          userId: user.uid,
          userRole: UserRoleValues.client,
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
          userRole: UserRoleValues.client,
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
