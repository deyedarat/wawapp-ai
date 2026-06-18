/**
 * Admin Reset Driver Dispatch State
 *
 * Callable Cloud Function that releases a driver stuck in dispatch state.
 * This bypasses Firestore Rules (which block client-side writes to driver_dispatch_state).
 *
 * Use case: Driver is stuck as "busy" with an order that was cancelled/completed
 * but the dispatch state was not cleaned up properly.
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { releaseDriverState } from '../dispatch/state';

export const adminResetDriverDispatch = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated'
    );
  }

  // Require admin role
  const userClaims = context.auth.token;
  if (!userClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can reset driver dispatch state'
    );
  }

  const { driverId } = data;

  if (!driverId || typeof driverId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide a valid driver ID'
    );
  }

  try {
    const db = admin.firestore();

    // Verify driver exists
    const driverDoc = await db.collection('drivers').doc(driverId).get();
    if (!driverDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Driver not found'
      );
    }

    // Get current state for audit log
    const stateDoc = await db.collection('driver_dispatch_state').doc(driverId).get();
    const previousState = stateDoc.exists ? stateDoc.data() : null;

    // Release the driver state
    await releaseDriverState(driverId);

    // Also cancel any active offers for this driver (prevent ghost notifications)
    if (previousState?.activeOfferId) {
      const offerRef = db.collection('dispatch_offers').doc(previousState.activeOfferId);
      const offerDoc = await offerRef.get();
      if (offerDoc.exists && offerDoc.data()?.status === 'sent') {
        await offerRef.update({
          status: 'expired',
          respondedAt: admin.firestore.Timestamp.now(),
        });
      }
    }

    // Log the action
    await db.collection('admin_actions').add({
      action: 'resetDriverDispatch',
      driverId,
      previousState: previousState ?? 'no_state_doc',
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('[AdminResetDriverDispatch] Driver dispatch state reset', {
      driver_id: driverId,
      admin_id: context.auth.uid,
      previous_status: previousState?.status ?? 'none',
      previous_order: previousState?.activeOrderId ?? 'none',
    });

    return {
      success: true,
      message: `Driver ${driverId} dispatch state has been reset`,
      previousState: previousState ? {
        status: previousState.status,
        activeOrderId: previousState.activeOrderId,
        activeOfferId: previousState.activeOfferId,
      } : null,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('[AdminResetDriverDispatch] Error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to reset driver dispatch state'
    );
  }
});
