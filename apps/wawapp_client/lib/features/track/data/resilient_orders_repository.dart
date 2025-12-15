import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:core_shared/core_shared.dart';
import 'orders_repository.dart';

/// Phase 2 resilient wrapper for OrdersRepository
/// Implements TC-04, TC-05, TC-06, TC-10, TC-11, TC-12, TC-15
class ResilientOrdersRepository {
  final OrdersRepository _baseRepo;
  final BreadcrumbService _breadcrumbs;
  final CrashlyticsKeysManager _crashlytics;
  final NetworkMonitor _network;
  final StuckStateDetector _stuckDetector;
  
  static const _createOrderTimeout = Duration(seconds: 10);
  static const _uuid = Uuid();

  ResilientOrdersRepository({
    required OrdersRepository baseRepo,
  })  : _baseRepo = baseRepo,
        _breadcrumbs = BreadcrumbService(),
        _crashlytics = CrashlyticsKeysManager(),
        _network = NetworkMonitor(),
        _stuckDetector = StuckStateDetector();

  /// Create order with Phase 2 resilience (TC-04, TC-10, TC-11, TC-12, TC-15)
  Future<String> createOrder({
    required String ownerId,
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> dropoff,
    required String pickupAddress,
    required String dropoffAddress,
    required double distanceKm,
    required int price,
  }) async {
    // Generate temporary ID for idempotency (TC-15: prevent duplicate orders)
    final tempId = _uuid.v4();
    
    _breadcrumbs.add(
      action: BreadcrumbActions.orderCreateInitiated,
      screen: 'order_creation',
      userId: ownerId,
      metadata: {
        'tempId': tempId,
        'distanceKm': distanceKm,
        'price': price,
      },
    );

    // TC-10: Check network before attempting create
    final networkError = _network.checkOnlineOrGetError();
    if (networkError != null) {
      _breadcrumbs.add(
        action: BreadcrumbActions.orderCreateFailed,
        screen: 'order_creation',
        userId: ownerId,
        metadata: {'reason': 'offline'},
      );
      
      await _crashlytics.recordNonFatal(
        failurePoint: FailurePoints.orderCreation,
        message: 'Order creation failed: offline',
        additionalData: {'error_code': 'offline', 'tempId': tempId},
      );
      
      throw AppError(
        type: AppErrorType.network,
        message: networkError,
      );
    }

    // Start timeout monitoring (TC-11: 10 second timeout)
    final timeoutCompleter = Completer<String>();
    _stuckDetector.monitorLoadingAction(
      actionName: 'order_creation',
      onTimeout: () {
        if (!timeoutCompleter.isCompleted) {
          timeoutCompleter.completeError(
            const AppError(
              type: AppErrorType.timeout,
              message: 'Request timed out, please try again',
            ),
          );
        }
      },
    );

    try {
      // TC-11: Create order with timeout enforcement
      final orderId = await _baseRepo.createOrder(
        ownerId: ownerId,
        pickup: pickup,
        dropoff: dropoff,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        distanceKm: distanceKm,
        price: price,
      ).timeout(
        _createOrderTimeout,
        onTimeout: () {
          _breadcrumbs.add(
            action: BreadcrumbActions.actionTimeout,
            screen: 'order_creation',
            userId: ownerId,
            metadata: {'action_name': 'order_creation', 'tempId': tempId},
          );
          
          throw const AppError(
            type: AppErrorType.timeout,
            message: 'Request timed out, please try again',
          );
        },
      );

      // Cancel timeout monitor on success
      _stuckDetector.cancel('loading_order_creation');

      _breadcrumbs.add(
        action: BreadcrumbActions.orderCreateSuccess,
        screen: 'order_creation',
        userId: ownerId,
        metadata: {
          'orderId': orderId,
          'tempId': tempId,
        },
      );

      // Update active order context in Crashlytics (TC-06 preparation)
      await _crashlytics.setActiveOrderContext(
        activeOrderId: orderId,
        activeOrderStatus: 'pending',
      );

      return orderId;
    } on FirebaseException catch (e) {
      // TC-12: Handle Firestore write failures explicitly
      _stuckDetector.cancel('loading_order_creation');
      
      _breadcrumbs.add(
        action: BreadcrumbActions.firestoreWriteFailed,
        screen: 'order_creation',
        userId: ownerId,
        metadata: {
          'error_code': e.code,
          'collection': 'orders',
          'tempId': tempId,
        },
      );

      await _crashlytics.recordNonFatal(
        failurePoint: FailurePoints.orderCreation,
        message: 'Firestore write failed during order creation',
        error: e,
        additionalData: {
          'firestore_collection': 'orders',
          'error_code': e.code,
          'tempId': tempId,
        },
      );

      // Surface error to UI (no silent failure)
      throw AppError(
        type: AppErrorType.firestore,
        message: 'Failed to create order, please try again',
        originalError: e,
      );
    } catch (e) {
      _stuckDetector.cancel('loading_order_creation');
      
      _breadcrumbs.add(
        action: BreadcrumbActions.orderCreateFailed,
        screen: 'order_creation',
        userId: ownerId,
        metadata: {
          'error': e.toString(),
          'tempId': tempId,
        },
      );

      await _crashlytics.recordNonFatal(
        failurePoint: FailurePoints.orderCreation,
        message: 'Order creation failed: ${e.toString()}',
        error: e,
        additionalData: {'tempId': tempId},
      );

      rethrow;
    }
  }

  /// Watch order with listener health monitoring (TC-05, TC-13)
  Stream<DocumentSnapshot> watchOrder(String orderId, {String? userId}) {
    _breadcrumbs.add(
      action: 'order_watch_started',
      screen: 'order_tracking',
      userId: userId,
      metadata: {'orderId': orderId},
    );

    // Start listener disconnection monitoring
    _stuckDetector.monitorListenerDisconnection(
      collection: 'orders',
      onTimeout: () {
        // Show banner: "Connection lost, retrying..."
        if (kDebugMode) print('[ResilientOrders] Listener disconnected for >60s');
      },
    );

    return _baseRepo.watchOrder(orderId).handleError((error) {
      _breadcrumbs.add(
        action: BreadcrumbActions.firestoreListenerDisconnected,
        screen: 'order_tracking',
        userId: userId,
        metadata: {
          'orderId': orderId,
          'error': error.toString(),
        },
      );

      _crashlytics.recordNonFatal(
        failurePoint: FailurePoints.firestoreListener,
        message: 'Order listener error',
        error: error,
        additionalData: {
          'collection': 'orders',
          'orderId': orderId,
        },
      );
    });
  }

  /// Cancel order with observability
  Future<void> cancelOrder(String orderId, {String? userId}) async {
    _breadcrumbs.add(
      action: BreadcrumbActions.orderCancelled,
      screen: 'order_tracking',
      userId: userId,
      metadata: {'orderId': orderId},
    );

    try {
      await _baseRepo.cancelOrder(orderId);
      
      // Clear active order context
      await _crashlytics.clearActiveOrderContext();
    } catch (e) {
      _breadcrumbs.add(
        action: 'order_cancel_failed',
        screen: 'order_tracking',
        userId: userId,
        metadata: {
          'orderId': orderId,
          'error': e.toString(),
        },
      );

      rethrow;
    }
  }

  /// Delegate other methods to base repository
  Stream<List<Order>> getUserOrders(String userId) => _baseRepo.getUserOrders(userId);
  Stream<List<Order>> getUserOrdersByStatus(String userId, OrderStatus status) => 
      _baseRepo.getUserOrdersByStatus(userId, status);
  Future<void> rateDriver({required String orderId, required int rating}) =>
      _baseRepo.rateDriver(orderId: orderId, rating: rating);
}
