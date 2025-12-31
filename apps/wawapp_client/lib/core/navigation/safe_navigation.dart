import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../observability/crashlytics_observer.dart';

/// Safe navigation helper to prevent go_router empty stack crashes
class SafeNavigation {
  /// Safely pop with fallback to home if stack is empty
  static void safePop(BuildContext context, {String fallbackRoute = '/'}) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    CrashlyticsObserver.logNavigation(
      action: 'pop',
      from: currentRoute,
      to: fallbackRoute,
      canPop: context.canPop(),
      mounted: context.mounted,
    );

    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }

  /// Safely pop with result, fallback to home if stack is empty
  static void safePopWithResult<T>(BuildContext context, T result,
      {String fallbackRoute = '/'}) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    CrashlyticsObserver.logNavigation(
      action: 'pop_with_result',
      from: currentRoute,
      to: fallbackRoute,
      canPop: context.canPop(),
      mounted: context.mounted,
    );

    if (context.canPop()) {
      context.pop(result);
    } else {
      context.go(fallbackRoute);
    }
  }

  /// Safely close dialog/modal with Navigator.pop, with context validation
  static void safeDialogPop<T>(BuildContext context, [T? result]) {
    CrashlyticsObserver.logNavigation(
      action: 'dialog_pop',
      from: 'dialog',
      canPop: Navigator.canPop(context),
      mounted: context.mounted,
    );

    if (context.mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop(result);
    }
  }

  /// Safe navigation after logout - ensures single source of truth
  static void safeLogoutNavigation(BuildContext context) {
    CrashlyticsObserver.logNavigation(
      action: 'logout',
      from: GoRouterState.of(context).matchedLocation,
      to: '/login',
      canPop: context.canPop(),
      mounted: context.mounted,
    );

    // Always use go() for logout to reset the stack completely
    context.go('/login');
  }
}

/// Extension on BuildContext for convenient safe navigation
extension SafeNavigationExtension on BuildContext {
  /// Safely pop with fallback to home
  void safePop({String fallbackRoute = '/'}) {
    SafeNavigation.safePop(this, fallbackRoute: fallbackRoute);
  }

  /// Safely pop with result
  void safePopWithResult<T>(T result, {String fallbackRoute = '/'}) {
    SafeNavigation.safePopWithResult(this, result,
        fallbackRoute: fallbackRoute);
  }

  /// Safely close dialog
  void safeDialogPop<T>([T? result]) {
    SafeNavigation.safeDialogPop(this, result);
  }
}
