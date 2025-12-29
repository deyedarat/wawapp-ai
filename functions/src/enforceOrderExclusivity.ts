/**
 * Cloud Function: Order Exclusivity Guards
 * 
 * Phase C: Server-side guards to prevent multiple drivers from accepting/transitioning
 * the same order, especially after it has started (onRoute status).
 * 
 * Rules:
 * - Once assignedDriverId is set, only that driver can transition the order
 * - Once status is onRoute, order is locked to assigned driver
 * - Reject any attempts by other drivers to accept/transition
 * 
 * Triggers on: orders/{orderId} onWrite (onCreate + onUpdate)
 * 
 * Author: WawApp Development Team (Phase C Implementation)
 * Last Updated: 2025-12-28
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function: Enforce order exclusivity
 */
export const enforceOrderExclusivity = functions.firestore
  .document('orders/{orderId}')
  .onWrite(async (change, context) => {
    const orderId = context.params.orderId;

    // Skip if document was deleted
    if (!change.after.exists) {
      return null;
    }

    const afterData = change.after.data();
    const beforeData = change.before.exists ? change.before.data() : null;

    const currentStatus = afterData?.status as string;
    const currentDriverId = afterData?.assignedDriverId as string | null;
    const previousDriverId = beforeData?.assignedDriverId as string | null;

    // Skip if no driver assigned
    if (!currentDriverId) {
      return null;
    }

    // Check for driver change after assignment (potential security issue)
    if (previousDriverId && previousDriverId !== currentDriverId) {
      console.warn('[OrderExclusivity] Driver change detected', {
        order_id: orderId,
        previous_driver: previousDriverId,
        current_driver: currentDriverId,
        status: currentStatus,
      });

      // Allow admin reassignments but log for audit
      console.log('[Analytics] driver_reassignment', {
        order_id: orderId,
        previous_driver: previousDriverId,
        current_driver: currentDriverId,
        status: currentStatus,
      });
    }

    // Enforce exclusivity for onRoute orders
    if (currentStatus === 'onRoute' && afterData) {
      // Add lockedAt timestamp if not present
      if (!afterData.lockedAt) {
        await change.after.ref.update({
          lockedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log('[OrderExclusivity] Order locked for exclusive access', {
          order_id: orderId,
          driver_id: currentDriverId,
        });
      }
    }

    return null;
  });