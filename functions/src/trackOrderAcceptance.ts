/**
 * Cloud Function: Track Order Acceptance Timestamp
 * 
 * Phase B: Sets acceptedAt timestamp when order status changes to 'accepted'
 * and assignedDriverId is set for the first time.
 * 
 * Triggers on: orders/{orderId} onUpdate
 * 
 * Author: WawApp Development Team (Phase B Implementation)
 * Last Updated: 2025-12-28
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function: Trigger on order updates to track acceptance
 */
export const trackOrderAcceptance = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const orderId = context.params.orderId;

    const beforeStatus = beforeData.status as string;
    const afterStatus = afterData.status as string;
    const beforeDriverId = beforeData.assignedDriverId;
    const afterDriverId = afterData.assignedDriverId;

    // Check if order just became accepted with a driver assigned
    const justAccepted = 
      afterStatus === 'accepted' && 
      afterDriverId !== null && 
      (beforeStatus !== 'accepted' || beforeDriverId === null);

    if (!justAccepted) {
      return null;
    }

    // Check if acceptedAt is already set (avoid overwriting)
    if (afterData.acceptedAt) {
      console.log('[TrackAcceptance] Order already has acceptedAt timestamp', {
        order_id: orderId,
        accepted_at: afterData.acceptedAt,
      });
      return null;
    }

    console.log('[TrackAcceptance] Order just accepted, setting acceptedAt', {
      order_id: orderId,
      driver_id: afterDriverId,
      from_status: beforeStatus,
      to_status: afterStatus,
    });

    try {
      // Set acceptedAt timestamp
      await change.after.ref.update({
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        acceptConfirmSentAt: null, // Ensure this is null for Phase B
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log('[TrackAcceptance] acceptedAt timestamp set successfully', {
        order_id: orderId,
        driver_id: afterDriverId,
      });

      // Log analytics event
      console.log('[Analytics] order_acceptance_tracked', {
        order_id: orderId,
        driver_id: afterDriverId,
      });

    } catch (error) {
      console.error('[TrackAcceptance] Failed to set acceptedAt timestamp', {
        order_id: orderId,
        driver_id: afterDriverId,
        error: error,
      });
    }

    return null;
  });