import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/order.dart' as app_order;
import '../../features/home/driver_home_screen.dart';
import '../../features/nearby/nearby_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import '../../features/auth/auth_gate.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/create_pin_screen.dart';
import '../../features/active/active_order_screen.dart';
import '../../features/earnings/driver_earnings_screen.dart';
import '../../features/history/driver_history_screen.dart';
import '../../features/history/order_details_screen.dart';
import 'navigator.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const AuthGate(child: DriverHomeScreen()),
      ),
      GoRoute(
        path: '/nearby',
        name: 'nearby',
        builder: (context, state) => const NearbyScreen(),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/otp',
        name: 'otp',
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: '/create-pin',
        name: 'createPin',
        builder: (context, state) => const CreatePinScreen(),
      ),
      GoRoute(
        path: '/active-order',
        name: 'activeOrder',
        builder: (context, state) => const ActiveOrderScreen(),
      ),
      GoRoute(
        path: '/earnings',
        name: 'earnings',
        builder: (context, state) => const DriverEarningsScreen(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const DriverHistoryScreen(),
      ),
      GoRoute(
        path: '/order-details',
        name: 'orderDetails',
        builder: (context, state) {
          final order = state.extra as app_order.Order;
          return OrderDetailsScreen(order: order);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
