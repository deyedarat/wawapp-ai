/**
 * notifyNewOrder v2.0 — Dispatch Engine Integration
 *
 * BREAKING CHANGE: No longer sends FCM directly.
 * Instead, enqueues order in dispatch system.
 *
 * Previous behavior:
 * - Immediately sent FCM to all nearby drivers (broadcast)
 * - Created dispatch_offers as logging only
 *
 * New behavior:
 * - Adds order to dispatch_queue
 * - Dispatch engine handles wave-based sending
 * - Zero duplicate notifications
 *
 * @author WawApp Development Team
 * @version 2.0.0
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';
import { safeEnqueueOrder } from './dispatch';

export const notifyNewOrderV2 = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snapshot, context) => {
    const orderId = context.params.orderId;
    const orderData = snapshot.data();

    console.log('[NotifyNewOrderV2] New order created', {
      order_id: orderId,
      status: orderData.status,
      created_at: orderData.createdAt,
    });

    // Only process orders in 'matching' or 'assigning' status
    if (orderData.status !== 'matching' && orderData.status !== 'assigning') {
      console.log('[NotifyNewOrderV2] Order not in matching/assigning status, skipping', {
        order_id: orderId,
        status: orderData.status,
      });
      return null;
    }

    // Normalize: convert 'assigning' to 'matching' so dispatch engine works correctly
    if (orderData.status === 'assigning') {
      console.log('[NotifyNewOrderV2] Normalizing status from assigning to matching', {
        order_id: orderId,
      });
      await snapshot.ref.update({ status: 'matching', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      orderData.status = 'matching';
    }

    // Validate pickup location (fast pre-check before full intake)
    const pickupLat = orderData.pickup?.lat;
    const pickupLng = orderData.pickup?.lng;

    if (!pickupLat || !pickupLng) {
      console.warn('[NotifyNewOrderV2] Order missing pickup coordinates', {
        order_id: orderId,
        pickup: orderData.pickup,
      });
      return null;
    }

    try {
      // Safe intake: normalize → validate → enqueue (or quarantine)
      const enqueued = await safeEnqueueOrder(orderId, orderData);

      if (enqueued) {
        console.log('[NotifyNewOrderV2] Order enqueued for dispatch', {
          order_id: orderId,
        });
      } else {
        console.warn('[NotifyNewOrderV2] Order quarantined — see dispatch_intake_failures', {
          order_id: orderId,
        });
      }

      return null;
    } catch (error: any) {
      console.error('[NotifyNewOrderV2] Failed to enqueue order', {
        order_id: orderId,
        error: error.message,
      });

      // Don't throw — let dispatch retry mechanism handle it
      return null;
    }
  });
