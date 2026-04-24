import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core_shared/core_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../features/orders/models/dispatch_offer.dart';
import 'acceptance_lock_manager.dart';
import 'analytics_service.dart';
import 'notification_method_channel.dart';

final ordersServiceProvider = Provider<OrdersService>((ref) {
  return OrdersService();
});

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Recursively cast Map<Object?, Object?> to Map<String, dynamic>
  static Map<String, dynamic> _deepCastMap(Map map) {
    return map.map((key, value) {
      if (value is Map) return MapEntry(key.toString(), _deepCastMap(value));
      if (value is List)
        return MapEntry(key.toString(),
            value.map((e) => e is Map ? _deepCastMap(e) : e).toList());
      return MapEntry(key.toString(), value);
    });
  }

  Future<List<Order>> getNearbyOrders(Position driverPosition) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        dev.log('[Matching] ❌ getNearbyOrders: No authenticated user');
      }
      return [];
    }

    if (kDebugMode) {
      dev.log('[Matching] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      dev.log('[Matching] 🔍 getNearbyOrders (Cloud Function) called');
      dev.log('[Matching] 📍 Driver ID: ${user.uid}');
      dev.log(
          '[Matching] 📍 Driver position: lat=${driverPosition.latitude.toStringAsFixed(6)}, lng=${driverPosition.longitude.toStringAsFixed(6)}');
    }

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getNearbyOrders');
      final result = await callable.call({
        'lat': driverPosition.latitude,
        'lng': driverPosition.longitude,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final rawOrders = (data['orders'] as List<dynamic>?) ?? [];

      if (kDebugMode) {
        dev.log(
            '[Matching] ✅ Cloud Function returned ${rawOrders.length} orders');
      }

      final orders = rawOrders.map((o) {
        final orderMap = _deepCastMap(o as Map);

        // Handle Timestamp conversion if necessary
        // Cloud Functions might return ISO strings or Maps for Timestamps
        if (orderMap['createdAt'] is String) {
          orderMap['createdAt'] =
              Timestamp.fromDate(DateTime.parse(orderMap['createdAt']));
        } else if (orderMap['createdAt'] is Map) {
          // Handle {_seconds: ..., _nanoseconds: ...} structure if present
          final t = orderMap['createdAt'];
          if (t['_seconds'] != null) {
            orderMap['createdAt'] =
                Timestamp(t['_seconds'], t['_nanoseconds'] ?? 0);
          }
        }

        // Ensure ID is passed correctly (Cloud Function returns 'id' field)
        final id = orderMap['id'];
        return Order.fromFirestoreWithId(id, orderMap);
      }).toList();

      return orders;
    } catch (e, stack) {
      if (kDebugMode) {
        dev.log('[Matching] ❌ Error calling Cloud Function: $e');
        dev.log('[Matching] ❌ Stack: $stack');
      }
      print('[NEARBY_PROVIDER] ❌ ERROR: $e');
      // Return empty list on error to avoid crashing UI
      return [];
    }
  }

  Future<void> acceptOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AppError(
          type: AppErrorType.permissionDenied,
          message: 'Driver not authenticated');
    }

    // Set acceptance lock immediately (before server call) to prevent race condition
    // This ensures that if another order notification arrives while this acceptance
    // is in progress, it will be silently rejected by the notification handler
    await AcceptanceLockManager.setAcceptanceLock(orderId);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('acceptOrder');
      await callable.call({'orderId': orderId});

      // Log analytics event after successful acceptance
      AnalyticsService.instance.logOrderAcceptedByDriver(orderId: orderId);

      // Set native active trip flag so MyFirebaseMessagingService suppresses new offers
      NotificationMethodChannel.setActiveTripFlag(true);

      // Clear lock after 5 seconds (successful acceptance)
      // This gives enough time for Firestore to update and prevents duplicate notifications
      Future.delayed(const Duration(seconds: 5), () {
        AcceptanceLockManager.clearLock();
      });
    } on FirebaseFunctionsException catch (e) {
      // Acceptance failed - clear lock immediately
      await AcceptanceLockManager.clearLock();

      if (e.code == 'failed-precondition') {
        throw const AppError(
            type: AppErrorType.permissionDenied,
            message: 'Order was already taken');
      }
      throw AppError.from(e);
    } on Object catch (e) {
      // Other error - clear lock immediately
      await AcceptanceLockManager.clearLock();

      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }

  Future<void> transition(String orderId, OrderStatus to) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw const AppError(
              type: AppErrorType.notFound, message: 'Order not found');
        }

        final currentStatus =
            OrderStatus.fromFirestore(orderDoc.data()!['status'] as String);

        if (!currentStatus.canTransitionTo(to)) {
          throw const AppError(
              type: AppErrorType.permissionDenied,
              message: 'Invalid status transition');
        }

        final update = to.createTransitionUpdate();
        transaction.update(orderRef, update);
      });

      // Log analytics event for completed orders
      if (to == OrderStatus.completed) {
        AnalyticsService.instance.logOrderCompletedByDriver(orderId: orderId);
        // Clear native active trip flag — driver is available again
        NotificationMethodChannel.setActiveTripFlag(false);
      }
    } on Object catch (e) {
      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }

  Future<void> cancelOrder(String orderId,
      {required CancelReason reason}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AppError(
          type: AppErrorType.permissionDenied,
          message: 'Driver not authenticated');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw const AppError(
              type: AppErrorType.notFound, message: 'Order not found');
        }

        final data = orderDoc.data()!;
        final driverId = data['driverId'] as String?;

        if (driverId != user.uid) {
          throw const AppError(
              type: AppErrorType.permissionDenied,
              message: 'Not authorized to cancel this order');
        }

        final currentStatus =
            OrderStatus.fromFirestore(data['status'] as String);

        if (!currentStatus.canDriverCancel) {
          throw const AppError(
              type: AppErrorType.permissionDenied,
              message: 'Cannot cancel order in current status');
        }

        transaction.update(
          orderRef,
          {
            ...OrderStatus.cancelledByDriver.createTransitionUpdate(),
            'cancelReason': reason.firestoreValue,
          },
        );
      });

      // Log analytics event after successful cancellation
      AnalyticsService.instance.logOrderCancelledByDriver(orderId: orderId);

      // Clear native active trip flag — driver is available again
      NotificationMethodChannel.setActiveTripFlag(false);
    } on Object catch (e) {
      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }

  Stream<List<Order>> getDriverActiveOrders(String driverId) {
    if (kDebugMode) {
      dev.log('[Matching] getDriverActiveOrders called for driver: $driverId');
      dev.log(
          '[Matching] Query intent: driverId=$driverId, status IN [accepted, onRoute]');
    }

    // REQUIRED COMPOSITE INDEX: orders [driverId ASC, status ASC]
    // Note: whereIn queries may auto-create this index, but explicitly defined in firestore.indexes.json
    // Deploy via: firebase deploy --only firestore:indexes
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          OrderStatus.accepted.toFirestore(),
          OrderStatus.onRoute.toFirestore(),
        ])
        .snapshots()
        .map((snapshot) {
          if (kDebugMode) {
            dev.log(
                '[Matching] Active orders snapshot: ${snapshot.docs.length} documents');
          }

          final orders = <Order>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              final order = Order.fromFirestoreWithId(doc.id, data);
              orders.add(order);

              if (kDebugMode) {
                final createdAt = data['createdAt'];
                dev.log(
                    '[Matching] Active order ${order.id}: status=${order.status}, createdAt=$createdAt, price=${order.price}');
              }
            } on Object catch (e) {
              if (kDebugMode) {
                dev.log('[Matching] Error parsing active order ${doc.id}: $e');
              }
            }
          }

          if (kDebugMode) {
            if (orders.isNotEmpty) {
              final orderStatuses = orders
                  .map((o) =>
                      '${o.id != null && o.id!.length > 6 ? o.id!.substring(o.id!.length - 6) : o.id ?? 'N/A'}:${o.status}')
                  .join(', ');
              dev.log(
                  '[Matching] Final active orders for driver $driverId: [$orderStatuses]');
            } else {
              dev.log('[Matching] No active orders for driver $driverId');
            }
          }

          return orders;
        });
  }

  // ============================================================================
  // V2 DISPATCH ENGINE METHODS
  // ============================================================================

  /// Accept an offer (v2.0 - offer-based dispatch)
  Future<void> acceptOfferV2({
    required String offerId,
    required String orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AppError(
          type: AppErrorType.permissionDenied,
          message: 'Driver not authenticated');
    }

    // Set acceptance lock immediately to prevent race condition
    await AcceptanceLockManager.setAcceptanceLock(orderId);

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('acceptOrderV2');
      final result = await callable.call({
        'orderId': orderId,
        'offerId': offerId,
      });

      if (result.data['success'] != true) {
        throw AppError(
          type: AppErrorType.unknown,
          message: result.data['message'] ?? 'فشل قبول العرض',
        );
      }

      // Log analytics event after successful acceptance
      AnalyticsService.instance.logOrderAcceptedByDriver(orderId: orderId);

      // Set native active trip flag so MyFirebaseMessagingService suppresses new offers
      NotificationMethodChannel.setActiveTripFlag(true);

      // Clear lock after 5 seconds (successful acceptance)
      Future.delayed(const Duration(seconds: 5), () {
        AcceptanceLockManager.clearLock();
      });
    } on FirebaseFunctionsException catch (e) {
      // Acceptance failed - clear lock immediately
      await AcceptanceLockManager.clearLock();

      // Map error codes to user-friendly messages
      if (e.code == 'invalid-argument' &&
          e.message?.contains('offerId') == true) {
        throw const AppError(
          type: AppErrorType.permissionDenied,
          message: 'يرجى تحديث التطبيق للإصدار الأحدث',
        );
      } else if (e.message?.contains('offer_expired') == true) {
        throw const AppError(
          type: AppErrorType.permissionDenied,
          message: 'انتهت صلاحية العرض',
        );
      } else if (e.message?.contains('already_accepted') == true) {
        throw const AppError(
          type: AppErrorType.permissionDenied,
          message: 'تم قبول الطلب من قبل سائق آخر',
        );
      } else if (e.message?.contains('driver_busy') == true) {
        throw const AppError(
          type: AppErrorType.permissionDenied,
          message: 'لديك طلب نشط بالفعل',
        );
      }
      throw AppError.from(e);
    } on Object catch (e) {
      // Other error - clear lock immediately
      await AcceptanceLockManager.clearLock();

      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }

  /// Reject an offer (v2.0)
  Future<void> rejectOffer({required String offerId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AppError(
          type: AppErrorType.permissionDenied,
          message: 'Driver not authenticated');
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('rejectOffer');
      final result = await callable.call({'offerId': offerId});

      if (result.data['success'] != true) {
        throw AppError(
          type: AppErrorType.unknown,
          message: result.data['message'] ?? 'فشل رفض العرض',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      throw AppError.from(e);
    } on Object catch (e) {
      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }

  /// Watch dispatch offers for this driver (v2.0)
  Stream<List<DispatchOffer>> watchMyOffers(String driverId) {
    if (kDebugMode) {
      dev.log('[DispatchV2] watchMyOffers called for driver: $driverId');
    }

    // REQUIRED COMPOSITE INDEX: dispatch_offers [driverId ASC, status ASC, expiresAt ASC]
    return _firestore
        .collection('dispatch_offers')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'sent')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        dev.log(
            '[DispatchV2] Dispatch offers snapshot: ${snapshot.docs.length} documents');
      }

      final offers = <DispatchOffer>[];
      for (final doc in snapshot.docs) {
        try {
          final offer = DispatchOffer.fromFirestore(doc);

          // Filter out expired offers
          if (offer.isValid) {
            offers.add(offer);

            if (kDebugMode) {
              dev.log(
                  '[DispatchV2] Offer ${offer.offerId}: orderId=${offer.orderId}, round=${offer.round}, remaining=${offer.remainingSeconds}s');
            }
          } else {
            if (kDebugMode) {
              dev.log('[DispatchV2] Filtered out expired offer: ${offer.offerId}');
            }
          }
        } on Object catch (e) {
          if (kDebugMode) {
            dev.log('[DispatchV2] Error parsing offer ${doc.id}: $e');
          }
        }
      }

      if (kDebugMode) {
        dev.log('[DispatchV2] Final valid offers: ${offers.length}');
      }

      return offers;
    });
  }
}
