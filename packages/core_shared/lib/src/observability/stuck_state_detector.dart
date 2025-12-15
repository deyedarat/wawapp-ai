import 'dart:async';
import 'package:flutter/foundation.dart';
import 'breadcrumb_service.dart';
import 'crashlytics_keys_manager.dart';

/// Detects stuck states and triggers alerts per Phase 2 thresholds
class StuckStateDetector {
  static final StuckStateDetector _instance = StuckStateDetector._internal();
  factory StuckStateDetector() => _instance;
  StuckStateDetector._internal();

  final _breadcrumbs = BreadcrumbService();
  final _crashlytics = CrashlyticsKeysManager();
  final Map<String, Timer> _activeTimers = {};
  final Map<String, VoidCallback> _timeoutCallbacks = {};

  /// Phase 2 Thresholds (in seconds)
  static const orderPendingThreshold = 600; // 10 minutes
  static const orderAcceptingThreshold = 120; // 2 minutes
  static const loadingSpinnerThreshold = 15; // 15 seconds
  static const driverToggleThreshold = 5; // 5 seconds
  static const paymentProcessingThreshold = 30; // 30 seconds
  static const listenerDisconnectedThreshold = 60; // 60 seconds

  /// Start monitoring for order stuck in pending state
  void monitorOrderPending({
    required String orderId,
    required VoidCallback onTimeout,
  }) {
    _startTimer(
      key: 'order_pending_$orderId',
      duration: Duration(seconds: orderPendingThreshold),
      onTimeout: () {
        _breadcrumbs.add(
          action: BreadcrumbActions.orderStuckPending,
          screen: 'order_tracking',
          metadata: {'orderId': orderId},
        );
        
        _crashlytics.recordNonFatal(
          failurePoint: 'order_stuck_pending',
          message: 'Order $orderId stuck in pending state for >10 minutes',
          additionalData: {'orderId': orderId, 'threshold_seconds': orderPendingThreshold},
        );
        
        onTimeout();
      },
    );
  }

  /// Start monitoring for order stuck in accepting state
  void monitorOrderAccepting({
    required String orderId,
    required String driverId,
    required VoidCallback onTimeout,
  }) {
    _startTimer(
      key: 'order_accepting_$orderId',
      duration: Duration(seconds: orderAcceptingThreshold),
      onTimeout: () {
        _breadcrumbs.add(
          action: BreadcrumbActions.orderStuckAccepting,
          screen: 'order_tracking',
          metadata: {'orderId': orderId, 'driverId': driverId},
        );
        
        _crashlytics.recordNonFatal(
          failurePoint: 'order_stuck_accepting',
          message: 'Order $orderId stuck in accepting state for >2 minutes',
          additionalData: {
            'orderId': orderId,
            'driverId': driverId,
            'threshold_seconds': orderAcceptingThreshold,
          },
        );
        
        onTimeout();
      },
    );
  }

  /// Start monitoring for loading spinner timeout
  void monitorLoadingAction({
    required String actionName,
    required VoidCallback onTimeout,
  }) {
    _startTimer(
      key: 'loading_$actionName',
      duration: Duration(seconds: loadingSpinnerThreshold),
      onTimeout: () {
        _breadcrumbs.add(
          action: BreadcrumbActions.actionTimeout,
          screen: 'unknown',
          metadata: {'action_name': actionName},
        );
        
        _crashlytics.recordNonFatal(
          failurePoint: FailurePoints.networkTimeout,
          message: 'Action timeout: $actionName exceeded 15 seconds',
          additionalData: {
            'action_name': actionName,
            'threshold_seconds': loadingSpinnerThreshold,
          },
        );
        
        onTimeout();
      },
    );
  }

  /// Start monitoring for driver availability toggle timeout
  void monitorDriverToggle({
    required bool targetOnlineState,
    required VoidCallback onTimeout,
  }) {
    _startTimer(
      key: 'driver_toggle',
      duration: Duration(seconds: driverToggleThreshold),
      onTimeout: () {
        _breadcrumbs.add(
          action: BreadcrumbActions.driverToggleTimeout,
          screen: 'driver_home',
          metadata: {'target_online_state': targetOnlineState},
        );
        
        _crashlytics.recordNonFatal(
          failurePoint: 'driver_toggle_timeout',
          message: 'Driver toggle to $targetOnlineState exceeded 5 seconds',
          additionalData: {
            'target_online_state': targetOnlineState,
            'threshold_seconds': driverToggleThreshold,
          },
        );
        
        onTimeout();
      },
    );
  }

  /// Start monitoring for payment processing timeout
  void monitorPaymentProcessing({
    required String orderId,
    required VoidCallback onTimeout,
  }) {
    _startTimer(
      key: 'payment_$orderId',
      duration: Duration(seconds: paymentProcessingThreshold),
      onTimeout: () {
        _breadcrumbs.add(
          action: BreadcrumbActions.paymentTimeout,
          screen: 'order_completion',
          metadata: {'orderId': orderId},
        );
        
        _crashlytics.recordNonFatal(
          failurePoint: FailurePoints.paymentProcessing,
          message: 'Payment processing timeout for order $orderId (>30 seconds)',
          additionalData: {
            'orderId': orderId,
            'threshold_seconds': paymentProcessingThreshold,
            'severity': 'P0', // Critical alert
          },
        );
        
        onTimeout();
      },
    );
  }

  /// Start monitoring for Firestore listener disconnection
  void monitorListenerDisconnection({
    required String collection,
    required VoidCallback onTimeout,
  }) {
    _startTimer(
      key: 'listener_$collection',
      duration: Duration(seconds: listenerDisconnectedThreshold),
      onTimeout: () {
        _breadcrumbs.add(
          action: BreadcrumbActions.firestoreListenerDisconnected,
          screen: 'unknown',
          metadata: {'collection': collection},
        );
        
        _crashlytics.recordNonFatal(
          failurePoint: FailurePoints.firestoreListener,
          message: 'Firestore listener disconnected for >60 seconds: $collection',
          additionalData: {
            'collection': collection,
            'threshold_seconds': listenerDisconnectedThreshold,
          },
        );
        
        onTimeout();
      },
    );
  }

  /// Cancel a specific timeout monitor
  void cancel(String key) {
    _activeTimers[key]?.cancel();
    _activeTimers.remove(key);
    _timeoutCallbacks.remove(key);
  }

  /// Cancel order-related monitors
  void cancelOrderMonitors(String orderId) {
    cancel('order_pending_$orderId');
    cancel('order_accepting_$orderId');
    cancel('payment_$orderId');
  }

  /// Cancel all active monitors
  void cancelAll() {
    for (var timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _timeoutCallbacks.clear();
  }

  // Private helper to start a timer
  void _startTimer({
    required String key,
    required Duration duration,
    required VoidCallback onTimeout,
  }) {
    // Cancel existing timer with same key if any
    cancel(key);

    _timeoutCallbacks[key] = onTimeout;
    _activeTimers[key] = Timer(duration, () {
      onTimeout();
      _activeTimers.remove(key);
      _timeoutCallbacks.remove(key);
    });
  }

  /// Check if a specific monitor is active
  bool isMonitoring(String key) => _activeTimers.containsKey(key);
}
