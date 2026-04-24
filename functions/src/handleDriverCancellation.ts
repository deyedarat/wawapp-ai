/**
 * Cloud Function: Handle Driver Cancellation
 *
 * Firestore trigger on orders/{orderId} update.
 * When a driver cancels (status → cancelledByDriver with cancelReason),
 * returns the order to 'matching' so other drivers can accept it,
 * and notifies the client with the cancellation reason.
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { safeEnqueueOrder } from './dispatch/intake';
import { releaseDriverState } from './dispatch/state';

const CANCEL_REASON_LABELS: Record<string, string> = {
  vehicle_breakdown: 'تعطل السيارة',
  customer_unreachable: 'العميل لا يرد',
  route_unsafe: 'الطريق غير آمن',
  other: 'سبب آخر',
};

export const handleDriverCancellation = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    // Only act on transitions TO cancelledByDriver (Firestore value: 'cancelled' or 'cancelledByDriver')
    if (before.status === after.status) return null;
    // Skip system cancellations (e.g. insufficient balance) — these should NOT return to matching
    if (after.status === 'cancelledBySystem') return null;
    if (after.status !== 'cancelled' && after.status !== 'cancelledByDriver') return null;
    // Avoid re-processing if already returned to matching
    if (before.status === 'matching') return null;

    const cancelReason: string = after.cancelReason || 'other';
    const previousDriverId: string = after.assignedDriverId || after.driverId || '';
    const ownerId: string = after.ownerId || '';

    console.log('[HandleDriverCancel] Driver cancelled order', {
      order_id: orderId,
      reason: cancelReason,
      driver_id: previousDriverId,
    });

    // Return order to matching pool
    const orderRef = admin.firestore().collection('orders').doc(orderId);
    await orderRef.update({
      status: 'matching',
      assignedDriverId: null,
      driverId: null,
      acceptedAt: null,
      cancelReason: null,
      cancelledAt: null,
      previousDriverId,
      previousCancelReason: cancelReason,
      reassignedAt: admin.firestore.FieldValue.serverTimestamp(),
      reassignReason: `driver_cancelled:${cancelReason}`,
      reminderCount: 0,
      lastReminderSentAt: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('[HandleDriverCancel] Order returned to matching', { order_id: orderId });

    // Release driver dispatch state so they can receive new offers
    if (previousDriverId) {
      await releaseDriverState(previousDriverId);
    }

    // Re-enqueue order into dispatch engine so it immediately gets new offers
    const freshOrder = await orderRef.get();
    if (freshOrder.exists) {
      await safeEnqueueOrder(orderId, freshOrder.data()!);
    }

    // Notify client
    if (ownerId) {
      const reasonLabel = CANCEL_REASON_LABELS[cancelReason] || cancelReason;
      try {
        const userDoc = await admin.firestore().collection('users').doc(ownerId).get();
        const fcmToken = userDoc.data()?.fcmToken as string | undefined;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: 'ألغى السائق الطلب',
              body: `السبب: ${reasonLabel}. جارِ البحث عن سائق آخر...`,
            },
            data: {
              type: 'driver_cancelled',
              orderId,
              cancelReason,
            },
            android: {
              priority: 'high',
              notification: { sound: 'default', channelId: 'order_updates' },
            },
            apns: { payload: { aps: { sound: 'default', badge: 1 } } },
          });
          console.log('[HandleDriverCancel] Client notified', { owner_id: ownerId });
        }
      } catch (err: any) {
        console.error('[HandleDriverCancel] FCM error', { owner_id: ownerId, error: err.message });
      }
    }

    return null;
  });
