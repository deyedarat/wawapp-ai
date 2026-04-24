/**
 * WawApp Dispatch Engine — Driver State Management
 *
 * Reusable helper to release a driver's dispatch lock after
 * trip completion, cancellation, or admin action.
 */

import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Release a driver's dispatch state so they become eligible for new offers.
 *
 * Clears activeOrderId, activeOfferId, acceptanceLock, and sets status = 'available'.
 * Safe to call even if the driver_dispatch_state doc doesn't exist (no-op).
 */
export async function releaseDriverState(driverId: string): Promise<void> {
  if (!driverId) return;

  const ref = db.collection('driver_dispatch_state').doc(driverId);
  const doc = await ref.get();

  if (!doc.exists) return;

  await ref.update({
    status: 'available',
    activeOrderId: null,
    activeOfferId: null,
    acceptanceLock: false,
    lockExpiresAt: null,
    updatedAt: admin.firestore.Timestamp.now(),
  });

  console.log('[DispatchState] Driver state released', { driver_id: driverId });
}
