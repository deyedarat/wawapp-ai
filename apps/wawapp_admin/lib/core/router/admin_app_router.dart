import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../features/auth/admin_login_screen.dart';
import '../../features/auth/admin_register_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/analytics/notification_analytics_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/drivers/drivers_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/live_ops/live_ops_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/finance/wallets/wallets_screen.dart';
import '../../features/finance/payouts/payouts_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/delivery_pricing_screen.dart';
import '../../features/settings/service_zones_screen.dart';
import '../../features/settings/working_hours_screen.dart';
import '../../features/settings/security_settings_screen.dart';
import '../../features/settings/admin_users_screen.dart';
import '../../features/settings/audit_log_screen.dart';
import '../../features/shared_places/shared_places_screen.dart';
import '../../providers/admin_auth_providers.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthLoading = authState.isLoading;
      final isAuthenticated = authState.maybeWhen(data: (user) => user != null, orElse: () => false);

      final isLoginRoute = state.matchedLocation == '/login';
      final isRegisterRoute = state.matchedLocation == '/register';

      // Block register route in production (SECURITY FIX)
      if (isRegisterRoute && AppConfigFactory.current.useStrictAuth) {
        return '/login';
      }

      // While auth is loading, redirect to login (it will re-redirect once loaded)
      if (isAuthLoading) {
        if (!isLoginRoute && !isRegisterRoute) return '/login';
        return null;
      }

      // Redirect to login if not authenticated (except register page in dev)
      final allowUnauthenticated = isLoginRoute || (isRegisterRoute && !AppConfigFactory.current.useStrictAuth);
      if (!isAuthenticated && !allowUnauthenticated) {
        return '/login';
      }

      // Redirect to dashboard if authenticated and on login/register page
      if (isAuthenticated && (isLoginRoute || isRegisterRoute)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', name: 'login', builder: (context, state) => const AdminLoginScreen()),
      // Register route — only available in dev mode (SECURITY FIX)
      if (!AppConfigFactory.current.useStrictAuth)
        GoRoute(path: '/register', name: 'register', builder: (context, state) => const AdminRegisterScreen()),
      GoRoute(path: '/', name: 'dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/orders', name: 'orders', builder: (context, state) => const OrdersScreen()),
      GoRoute(path: '/drivers', name: 'drivers', builder: (context, state) => const DriversScreen()),
      GoRoute(path: '/clients', name: 'clients', builder: (context, state) => const ClientsScreen()),
      GoRoute(path: '/live-ops', name: 'live-ops', builder: (context, state) => const LiveOpsScreen()),
      GoRoute(path: '/reports', name: 'reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(path: '/finance/wallets', name: 'wallets', builder: (context, state) => const WalletsScreen()),
      GoRoute(path: '/finance/payouts', name: 'payouts', builder: (context, state) => const PayoutsScreen()),
      // ── Settings (parent + sub-pages) ──
      GoRoute(path: '/settings', name: 'settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(
        path: '/settings/pricing',
        name: 'settings-pricing',
        builder: (context, state) => const DeliveryPricingScreen(),
      ),
      GoRoute(path: '/settings/zones', name: 'settings-zones', builder: (context, state) => const ServiceZonesScreen()),
      GoRoute(path: '/settings/hours', name: 'settings-hours', builder: (context, state) => const WorkingHoursScreen()),
      GoRoute(
        path: '/settings/security',
        name: 'settings-security',
        builder: (context, state) => const SecuritySettingsScreen(),
      ),
      // ── Notifications ──
      GoRoute(path: '/notifications', name: 'notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(
        path: '/notification-analytics',
        name: 'notificationAnalytics',
        builder: (context, state) => const NotificationAnalyticsScreen(),
      ),
      // ── Audit Log ──
      GoRoute(path: '/audit-log', name: 'audit-log', builder: (context, state) => const AuditLogScreen()),
      // ── Shared Places ──
      GoRoute(path: '/shared-places', name: 'shared-places', builder: (context, state) => const SharedPlacesScreen()),
      // ── Admin Users Management ──
      GoRoute(path: '/admin-users', name: 'admin-users', builder: (context, state) => const AdminUsersScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('الصفحة غير موجودة', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(state.uri.toString(), style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => context.go('/'), child: const Text('العودة للوحة التحكم')),
          ],
        ),
      ),
    ),
  );
});
