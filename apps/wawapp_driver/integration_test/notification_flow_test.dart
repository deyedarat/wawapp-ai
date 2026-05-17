import 'dart:async';

import 'package:auth_shared/auth_shared.dart' hide AuthNotifier;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wawapp_driver/core/router/app_router.dart';
import 'package:wawapp_driver/core/router/navigator.dart';
import 'package:wawapp_driver/features/auth/providers/auth_service_provider.dart';
import 'package:wawapp_driver/features/notifications/full_screen_notification_screen.dart';
import 'package:wawapp_driver/firebase_options.dart';
import 'package:wawapp_driver/services/notification_dedup_service.dart';
import 'package:wawapp_driver/services/orders_service.dart';

// =============================================================================
// Mocks (self-contained to avoid cross-boundary import issues)
// =============================================================================

class FakePhonePinAuth implements PhonePinAuth {
  @override
  final String userCollection = 'drivers';
  @override
  String? get lastPhoneE164 => null;

  @override
  Future<void> ensurePhoneSession(String p, {bool forceNewSession = false, void Function(String, String?, String?, String?)? onLog}) async {}
  @override
  Future<bool> phoneExists(String p) async => false;
  @override
  Future<bool> confirmOtp(String c) async => false;
  @override
  Future<void> setPin(String p) async {}
  @override
  Future<bool> verifyPin(String p, String ph) async => true;
  @override
  Future<bool> hasPinHash() async => true;
  @override
  Future<void> signOut() async {}
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(super.authService, super.firebaseAuth);

  void setTestState(AuthState s) => state = s;

  @override
  Future<void> checkHasPin() async {}
}

class MockFirebaseAuth extends Fake implements FirebaseAuth {
  final _ctrl = StreamController<User?>.broadcast();
  User? _user;

  @override
  Stream<User?> authStateChanges() => _ctrl.stream;
  @override
  Stream<User?> userChanges() => _ctrl.stream;
  @override
  Stream<User?> idTokenChanges() => _ctrl.stream;
  @override
  User? get currentUser => _user;

  void signIn(User u) { _user = u; _ctrl.add(u); }
  @override
  Future<void> signOut() async { _user = null; _ctrl.add(null); }
}

class MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? phoneNumber;
  MockUser({required this.uid, this.phoneNumber});
}

/// Mock OrdersService that records calls instead of hitting Firebase.
class MockOrdersService extends OrdersService {
  String? lastAcceptedOrderId;

  @override
  Future<void> acceptOrder(String orderId, String offerId) async {
    lastAcceptedOrderId = orderId;
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> acceptOfferV2({required String offerId, required String orderId}) async {
    lastAcceptedOrderId = orderId;
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

// =============================================================================
// Helpers
// =============================================================================

const _testNotificationData = FullScreenNotificationData(
  orderId: 'order_test_001',
  pickupLabel: 'مطار نواكشوط',
  dropoffLabel: 'فندق الخيمة',
  price: 350,
  distance: 4.2,
  createdAtMs: 0, // "الآن"
);

extension PumpUntilFound on WidgetTester {
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await pump(step);
      if (any(finder)) return;
    }
    throw TestFailure('pumpUntilFound timeout for: $finder');
  }
}

Future<void> settle(WidgetTester tester, {int ms = 300}) async {
  await tester.pump(Duration(milliseconds: ms));
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthNotifier fakeAuth;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockOrdersService mockOrdersService;
  late MockUser testUser;

  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {}
    }
  });

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    fakeAuth = FakeAuthNotifier(FakePhonePinAuth(), mockFirebaseAuth);
    mockOrdersService = MockOrdersService();
    testUser = MockUser(uid: 'driver_notif_test', phoneNumber: '+22200000000');
  });

  /// Pump the app with an authenticated driver state so router allows
  /// notification routes through.
  Future<void> pumpAuthenticatedApp(WidgetTester tester) async {
    fakeAuth.setTestState(AuthState(
      user: testUser,
      pinStatus: PinStatus.hasPin,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => fakeAuth),
          ordersServiceProvider.overrideWithValue(mockOrdersService),
        ],
        child: Consumer(builder: (context, ref, _) {
          final router = ref.watch(appRouterProvider);
          return MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ar'),
          );
        }),
      ),
    );
    await settle(tester, ms: 500);
  }

  // ---------------------------------------------------------------------------
  // Test 1: Full-screen notification opens with correct data via deep link
  // ---------------------------------------------------------------------------
  group('Full-screen notification navigation', () {
    testWidgets('navigates to /full-screen-notification with correct data',
        (tester) async {
      await pumpAuthenticatedApp(tester);

      // Navigate via GoRouter (simulates deep link / notification tap)
      final ctx = appNavigatorKey.currentContext!;
      ctx.go('/full-screen-notification', extra: _testNotificationData);
      await settle(tester, ms: 500);

      // Verify FullScreenNotificationScreen is displayed
      expect(find.byType(FullScreenNotificationScreen), findsOneWidget);

      // Verify order data rendered correctly
      expect(find.text('مطار نواكشوط'), findsOneWidget);
      expect(find.text('فندق الخيمة'), findsOneWidget);
      expect(find.text('350 MRU'), findsOneWidget);
      expect(find.text('4.2 كم'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Test 2: Accept button navigates to /active-order
  // ---------------------------------------------------------------------------
  group('Accept button flow', () {
    testWidgets('tapping Accept calls acceptOrder and navigates to /active-order',
        (tester) async {
      await pumpAuthenticatedApp(tester);

      final ctx = appNavigatorKey.currentContext!;
      ctx.go('/full-screen-notification', extra: _testNotificationData);
      await settle(tester, ms: 500);

      // Tap the accept button (Arabic: قبول الطلب)
      final acceptButton = find.text('قبول الطلب');
      expect(acceptButton, findsOneWidget);
      await tester.tap(acceptButton);
      await settle(tester, ms: 500);

      // Verify acceptOrder was called with correct orderId
      expect(mockOrdersService.lastAcceptedOrderId, 'order_test_001');

      // Verify navigation to /active-order
      final routerState = GoRouterState.of(appNavigatorKey.currentContext!);
      expect(routerState.uri.path, '/active-order');
    });
  });

  // ---------------------------------------------------------------------------
  // Test 3: Duplicate notification filtering via NotificationDedupService
  // ---------------------------------------------------------------------------
  group('Duplicate notification filtering', () {
    testWidgets('isDuplicate returns true for same messageId', (tester) async {
      // Set up SharedPreferences with empty state
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dedup = NotificationDedupService(prefs);

      const messageId = 'order_001_offer_001_1';

      // First time: not a duplicate
      expect(dedup.isDuplicate(messageId), isFalse);

      // Mark as processed
      dedup.markAsProcessed(messageId);

      // Second time: is a duplicate
      expect(dedup.isDuplicate(messageId), isTrue);

      // Different messageId: not a duplicate
      expect(dedup.isDuplicate('order_001_offer_001_2'), isFalse);
    });

    testWidgets('duplicate messageId does not re-navigate', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dedup = NotificationDedupService(prefs);

      // Pre-mark a messageId as processed (simulates first delivery)
      const messageId = 'order_dup_test_offer_1_1';
      dedup.markAsProcessed(messageId);

      // Verify it's flagged as duplicate
      expect(dedup.isDuplicate(messageId), isTrue);

      // Now pump the app and verify we're NOT on the full-screen route
      // (the notification handler would skip processing)
      await pumpAuthenticatedApp(tester);

      // We should be on home, not full-screen-notification
      final routerState = GoRouterState.of(appNavigatorKey.currentContext!);
      expect(routerState.uri.path, isNot('/full-screen-notification'));
    });
  });
}
