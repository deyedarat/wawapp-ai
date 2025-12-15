import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import 'package:geolocator/geolocator.dart';
import 'orders_service.dart';

/// Phase 2 resilient wrapper for driver OrdersService
/// Implements TC-07, TC-08, TC-09 (end-to-end, not foundation)
class ResilientOrdersService {
  final OrdersService _baseService;
  final BreadcrumbService _breadcrumbs;
  final CrashlyticsKeysManager _crashlytics;
  final NetworkMonitor _network;
  final StuckStateDetector _stuckDetector;
  final FirebaseFirestore _firestore;

  static const _acceptOrderTimeout = Duration(seconds: 10);
  static const _transitionTimeout = Duration(seconds: 10);

  ResilientOrdersService({
    required OrdersService baseService,
  })  : _baseService = baseService,
        _breadcrumbs = BreadcrumbService(),
        _crashlytics = CrashlyticsKeysManager(),
        _network = NetworkMonitor(),
        _stuckDetector = StuckStateDetector(),
        _firestore = FirebaseFirestore.instance;

  /// TC-07: Accept order with kill recovery
  Future<void> acceptOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AppError(
        type: AppErrorType.permissionDenied,
        message: 'Driver not authenticated',
      );
    }

    _breadcrumbs.add(
      action: BreadcrumbActions.orderAcceptTapped,
      screen: 'nearby_orders',
      userId: user.uid,
      metadata: {'orderId': orderId},
    );

    // Check network before attempting
    final networkError = _network.checkOnlineOrGetError();
    if (networkError != null) {
      _breadcrumbs.add(
        action: 'order_accept_failed',
        screen: 'nearby_orders',
        userId: user.uid,
        metadata: {'orderId': orderId, 'reason': 'offline'},
      );
      throw AppError(
        type: AppErrorType.network,
        message: networkError,
      );
    }

    // Start timeout monitoring (TC-07: stuck accepting threshold = 2 min)
    _stuckDetector.monitorOrderAccepting(
      orderId: orderId,
      driverId: user.uid,
      onTimeout: () {
        if (kDebugMode) print('[ResilientOrders] Order accepting timeout: $orderId');
      },
    );

    try {
      // Accept order with timeout enforcement
      await _baseService.acceptOrder(orderId).timeout(
        _acceptOrderTimeout,
        onTimeout: () {
          _breadcrumbs.add(
            action: BreadcrumbActions.actionTimeout,
            screen: 'nearby_orders',
            userId: user.uid,
            metadata: {'action_name': 'order_acceptance', 'orderId': orderId},
          );
          throw const AppError(
            type: AppErrorType.timeout,
            message: 'Request timed out, please try again',
          );
        },
      );

      // Cancel stuck state monitoring on success
      _stuckDetector.cancel('order_accepting_$orderId');

      // TC-07: Log successful acceptance and set active order context
      _breadcrumbs.add(
        action: BreadcrumbActions.orderAccepted,
        screen: 'nearby_orders',
        userId: user.uid,
        metadata: {'orderId': orderId},
      );

      await _crashlytics.setActiveOrderContext(
        activeOrderId: orderId,
        activeOrderStatus: 'accepted',
      );

      if (kDebugMode) print('[ResilientOrders] Order accepted: $orderId');
    } on FirebaseException catch (e) {
      _stuckDetector.cancel('order_accepting_$orderId');

      _breadcrumbs.add(
        action: BreadcrumbActions.firestoreWriteFailed,
        screen: 'nearby_orders',
        userId: user.uid,
        metadata: {
          'orderId': orderId,
          'error_code': e.code,
          'collection': 'orders',
        },
      );

      await _crashlytics.recordNonFatal(
        failurePoint: FailurePoints.driverAcceptance,
        message: 'Order acceptance failed: ${e.code}',
        error: e,
        additionalData: {
          'firestore_collection': 'orders',
          'error_code': e.code,
          'orderId': orderId,
        },
      );

      throw AppError(
        type: AppErrorType.firestore,
        message: e.code == 'permission-denied'
            ? 'Order was already taken'
            : 'Failed to accept order, please try again',
        originalError: e,
      );
    } catch (e) {
      _stuckDetector.cancel('order_accepting_$orderId');

      _breadcrumbs.add(
        action: 'order_accept_failed',
        screen: 'nearby_orders',
        userId: user.uid,
        metadata: {'orderId': orderId, 'error': e.toString()},
      );

      await _crashlytics.recordNonFatal(
        failurePoint: FailurePoints.driverAcceptance,
        message: 'Order acceptance failed: ${e.toString()}',
        error: e,
        additionalData: {'orderId': orderId},
      );

      rethrow;
    }
  }

  /// TC-08: Check if driver can go offline (block if active trip)
  Future<bool> canGoOffline() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Query for any orders where this driver is assigned and status is in_progress
      final activeTrips = await _firestore
          .collection('orders')
          .where('assignedDriverId', isEqualTo: user.uid)
          .where('status', isEqualTo: OrderStatus.inProgress.toFirestore())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (activeTrips.docs.isNotEmpty) {
        final orderId = activeTrips.docs.first.id;

        // TC-08: Log blocked attempt
        _breadcrumbs.add(
          action: BreadcrumbActions.goOfflineBlocked,
          screen: 'driver_home',
          userId: user.uid,
          metadata: {'active_trip_orderId': orderId},
        );

        await _crashlytics.recordNonFatal(
          failurePoint: 'go_offline_validation',
          message: 'Driver attempted to go offline during active trip',
          additionalData: {
            'driverId': user.uid,
            'active_trip_orderId': orderId,
          },
        );

        return false; // Block offline
      }

      return true; // Allow offline
    } catch (e) {
      if (kDebugMode) print('[ResilientOrders] Error checking active trips: $e');
      // On error, err on the side of caution and allow offline
      return true;
    }
  }

  /// TC-09: Complete trip with payment monitoring
  Future<void> completeTrip(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AppError(
        type: AppErrorType.permissionDenied,
        message: 'Driver not authenticated',
      );
    }

    _breadcrumbs.add(
      action: 'trip_complete_initiated',
      screen: 'active_order',
      userId: user.uid,
      metadata: {'orderId': orderId},
    );

    // TC-09: Start payment processing monitoring (30 sec threshold)
    _stuckDetector.monitorPaymentProcessing(
      orderId: orderId,
      onTimeout: () {
        if (kDebugMode) print('[ResilientOrders] Payment processing timeout: $orderId');
      },
    );

    try {
      // Transition order to completed with timeout
      await _baseService.transition(orderId, OrderStatus.completed).timeout(
        _transitionTimeout,
        onTimeout: () {
          _breadcrumbs.add(
            action: BreadcrumbActions.actionTimeout,
            screen: 'active_order',
            userId: user.uid,
            metadata: {'action_name': 'trip_completion', 'orderId': orderId},
          );
          throw const AppError(
            type: AppErrorType.timeout,
            message: 'Payment confirmation delayed, please contact support',
          );
        },
      );

      // Cancel payment monitoring on success
      _stuckDetector.cancel('payment_$orderId');

      // TC-09: Log successful completion
      _breadcrumbs.add(
        action: BreadcrumbActions.tripCompleted,
        screen: 'active_order',
        userId: user.uid,
        metadata: {'orderId': orderId},
      );

      // Clear active order context
      await _crashlytics.clearActiveOrderContext();

      if (kDebugMode) print('[ResilientOrders] Trip completed: $orderId');
    } on FirebaseException catch (e) {
      _stuckDetector.cancel('payment_$orderId');

      _breadcrumbs.add(
        action: BreadcrumbActions.firestoreWriteFailed,
        screen: 'active_order',
        userId: user.uid,
        metadata: {
          'orderId': orderId,
          'error_code': e.code,
          'collection': 'orders',
        },
      );

      await _crashlytics.recordNonFatal(
        failurePoint: FailurePoints.tripCompletion,
        message: 'Trip completion failed: ${e.code}',
        error: e,
        additionalData: {
          'firestore_collection': 'orders',
          'error_code': e.code,
          'orderId': orderId,
        },
      );

      throw AppError(
        type: AppErrorType.firestore,
        message: 'Failed to complete trip, please try again',
        originalError: e,
      );
    } catch (e) {
      _stuckDetector.cancel('payment_$orderId');

      _breadcrumbs.add(
        action: 'trip_complete_failed',
        screen: 'active_order',
        userId: user.uid,
        metadata: {'orderId': orderId, 'error': e.toString()},
      );

      await _crashlytics.recordNonFatal(
        failurePoint: FailurePoints.tripCompletion,
        message: 'Trip completion failed: ${e.toString()}',
        error: e,
        additionalData: {'orderId': orderId},
      );

      rethrow;
    }
  }

  /// Start trip (with observability)
  Future<void> startTrip(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _breadcrumbs.add(
      action: BreadcrumbActions.tripStarted,
      screen: 'active_order',
      userId: user.uid,
      metadata: {'orderId': orderId},
    );

    try {
      await _baseService.transition(orderId, OrderStatus.inProgress);
      
      // Update active order status
      await _crashlytics.setActiveOrderContext(
        activeOrderId: orderId,
        activeOrderStatus: 'in_progress',
      );
    } catch (e) {
      _breadcrumbs.add(
        action: 'trip_start_failed',
        screen: 'active_order',
        userId: user.uid,
        metadata: {'orderId': orderId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Delegate other methods to base service
  Stream<List<Order>> getNearbyOrders(Position driverPosition) {
    final user = FirebaseAuth.instance.currentUser;
    _breadcrumbs.add(
      action: BreadcrumbActions.orderListViewed,
      screen: 'nearby_orders',
      userId: user?.uid,
    );
    return _baseService.getNearbyOrders(driverPosition);
  }

  Future<void> transition(String orderId, OrderStatus to) =>
      _baseService.transition(orderId, to);
}

/// Provider for ResilientOrdersService
final resilientOrdersServiceProvider = Provider<ResilientOrdersService>((ref) {
  final baseService = ref.watch(ordersServiceProvider);
  return ResilientOrdersService(baseService: baseService);
});
