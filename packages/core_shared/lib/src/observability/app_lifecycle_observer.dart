import 'package:flutter/widgets.dart';
import 'breadcrumb_service.dart';
import 'crashlytics_keys_manager.dart';

/// Observes app lifecycle changes for Phase 2 resilience
class AppLifecycleObserver extends WidgetsBindingObserver {
  final _breadcrumbs = BreadcrumbService();
  final _crashlytics = CrashlyticsKeysManager();
  
  DateTime? _lastPausedTime;
  DateTime? _sessionStartTime;
  String? _activeOrderId;

  /// Initialize the observer
  void initialize() {
    _sessionStartTime = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    
    _breadcrumbs.add(
      action: 'app_launched',
      screen: 'system',
    );
  }

  /// Dispose the observer
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Set active order ID for lifecycle tracking
  void setActiveOrder(String? orderId) {
    _activeOrderId = orderId;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleResumed();
        break;
      case AppLifecycleState.inactive:
        // App is transitioning between states (not actionable)
        break;
      case AppLifecycleState.paused:
        _handlePaused();
        break;
      case AppLifecycleState.detached:
        _handleDetached();
        break;
      case AppLifecycleState.hidden:
        // App is hidden but still running
        break;
    }
  }

  void _handleResumed() {
    final now = DateTime.now();
    
    // Calculate background duration
    Duration? backgroundDuration;
    if (_lastPausedTime != null) {
      backgroundDuration = now.difference(_lastPausedTime!);
    }

    _breadcrumbs.add(
      action: BreadcrumbActions.appForegrounded,
      screen: 'system',
      metadata: {
        if (_activeOrderId != null) 'orderId': _activeOrderId!,
        if (backgroundDuration != null) 'background_duration_seconds': backgroundDuration.inSeconds,
      },
    );

    // Update session duration in Crashlytics
    if (_sessionStartTime != null) {
      _crashlytics.updateSessionDuration(now.difference(_sessionStartTime!));
    }

    // If backgrounded for >10 minutes, log it as significant event
    if (backgroundDuration != null && backgroundDuration.inMinutes >= 10) {
      _breadcrumbs.add(
        action: 'app_backgrounded_long_duration',
        screen: 'system',
        metadata: {
          'duration_minutes': backgroundDuration.inMinutes,
          if (_activeOrderId != null) 'orderId': _activeOrderId!,
        },
      );
    }
  }

  void _handlePaused() {
    _lastPausedTime = DateTime.now();
    
    _breadcrumbs.add(
      action: BreadcrumbActions.appBackgrounded,
      screen: 'system',
      metadata: {
        if (_activeOrderId != null) 'orderId': _activeOrderId!,
      },
    );
  }

  void _handleDetached() {
    _breadcrumbs.add(
      action: 'app_detached',
      screen: 'system',
      metadata: {
        if (_activeOrderId != null) 'orderId': _activeOrderId!,
      },
    );
  }

  /// Check if app was killed (call this on app startup)
  Future<void> checkIfAppWasKilled({String? userId}) async {
    // This should be called on app startup to detect if app was force-stopped
    // We can detect this by checking if there's a persisted "app_running" flag
    // For now, we'll log the detection event
    
    if (_activeOrderId != null) {
      _breadcrumbs.add(
        action: BreadcrumbActions.appKilledWithActiveOrder,
        screen: 'system',
        metadata: {'orderId': _activeOrderId!},
      );

      await _crashlytics.recordNonFatal(
        failurePoint: FailurePoints.appRestoration,
        message: 'App killed with active order: $_activeOrderId',
        additionalData: {'orderId': _activeOrderId!},
      );
    } else {
      _breadcrumbs.add(
        action: BreadcrumbActions.appKilledDetected,
        screen: 'system',
      );
    }
  }

  /// Get session duration
  Duration? getSessionDuration() {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }
}
