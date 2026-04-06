/**
 * Cloud Function: Monitor Accepted Orders (Phase D)
 *
 * Sends trip-start reminders to drivers every minute after acceptance.
 * Reassigns order back to matching pool if driver doesn't start within timeout.
 *
 * Rules:
 * - Reminder every 5 minutes after acceptance
 * - Timeout at 5 minutes (+ optional 2-min extension)
 * - On timeout: reset to matching, notify driver + client
 * - Idempotent: tracks reminderCount + lastReminderSentAt
 * - Stops immediately if status changes from 'accepted'
 *
 * Runs every 1 minute via Cloud Scheduler.
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

// Constants
const ACCEPTED_TIMEOUT_MINUTES = 5;
const REMINDER_INTERVAL_MINUTES = 5;
const MAX_EXTENSIONS_ALLOWED = 1;
const EXTENSION_DURATION_MINUTES = 2;
const BATCH_LIMIT = 50;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Send FCM to a driver (drivers collection)
 */
async function sendToDriver(
  driverId: string,
  title: string,
  body: string,
  data: Record<string, string>,
  channelId = 'order_updates'
): Promise<boolean> {
  try {
    const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
    const fcmToken = driverDoc.data()?.fcmToken as string | undefined;
    if (!fcmToken) return false;

    await admin.messaging().send({
      token: fcmToken,
      data: {
        ...data,
        title,
        body,
        notificationType: data.notificationType || data.type || '',
      },
      android: {
        priority: 'high',
        ttl: 120000,
      },
      apns: { payload: { aps: { sound: 'default', badge: 1, contentAvailable: true } } },
    });
    return true;
  } catch (err: any) {
    if (
      err.code === 'messaging/invalid-registration-token' ||
      err.code === 'messaging/registration-token-not-registered'
    ) {
      admin.firestore().collection('drivers').doc(driverId)
        .update({ fcmToken: admin.firestore.FieldValue.delete() })
        .catch(() => {});
    }
    console.error('[MonitorAccepted] FCM error (driver)', { driver_id: driverId, error: err.message });
    return false;
  }
}

/**
 * Send FCM to a client (users collection)
 */
async function sendToClient(
  clientId: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<boolean> {
  try {
    const userDoc = await admin.firestore().collection('users').doc(clientId).get();
    const fcmToken = userDoc.data()?.fcmToken as string | undefined;
    if (!fcmToken) return false;

    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,
      android: { priority: 'high', notification: { sound: 'default', channelId: 'order_updates' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
    return true;
  } catch (err: any) {
    if (
      err.code === 'messaging/invalid-registration-token' ||
      err.code === 'messaging/registration-token-not-registered'
    ) {
      admin.firestore().collection('users').doc(clientId)
        .update({ fcmToken: admin.firestore.FieldValue.delete() })
        .catch(() => {});
    }
    console.error('[MonitorAccepted] FCM error (client)', { client_id: clientId, error: err.message });
    return false;
  }
}

// ---------------------------------------------------------------------------
// Core: process a single accepted order
// ---------------------------------------------------------------------------

async function processAcceptedOrder(
  orderId: string,
  orderData: FirebaseFirestore.DocumentData,
  nowMs: number
): Promise<'reminded' | 'reassigned' | 'skipped'> {
  const db = admin.firestore();
  const orderRef = db.collection('orders').doc(orderId);

  const acceptedAtMs: number = orderData.acceptedAt?.toMillis?.() || 0;
  if (!acceptedAtMs) {
    console.warn('[MonitorAccepted] Missing acceptedAt', { order_id: orderId });
    return 'skipped';
  }

  const elapsedMs = nowMs - acceptedAtMs;
  const elapsedMinutes = elapsedMs / 60000;
  const extensions: number = orderData.extensionRequestCount || 0;
  const totalTimeoutMinutes =
    ACCEPTED_TIMEOUT_MINUTES + Math.min(extensions, MAX_EXTENSIONS_ALLOWED) * EXTENSION_DURATION_MINUTES;
  const remainingMinutes = Math.max(0, Math.ceil(totalTimeoutMinutes - elapsedMinutes));

  const assignedDriverId: string = orderData.assignedDriverId || orderData.driverId;
  const ownerId: string = orderData.ownerId;

  // ── Timeout → reassign ──
  if (elapsedMinutes >= totalTimeoutMinutes) {
    console.log('[MonitorAccepted] Timeout reached, reassigning', {
      order_id: orderId,
      elapsed_min: elapsedMinutes.toFixed(1),
      timeout_min: totalTimeoutMinutes,
      driver_id: assignedDriverId,
    });

    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(orderRef);
        if (!snap.exists) return;
        const current = snap.data()!;
        // Guard: only reassign if still accepted with same driver
        if (current.status !== 'accepted' || current.assignedDriverId !== assignedDriverId) return;

        tx.update(orderRef, {
          status: 'matching',
          assignedDriverId: null,
          driverId: null,
          acceptedAt: null,
          reassignedAt: admin.firestore.FieldValue.serverTimestamp(),
          reassignReason: 'accepted_timeout',
          previousDriverId: assignedDriverId,
          reminderCount: 0,
          lastReminderSentAt: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (txErr) {
      console.error('[MonitorAccepted] Reassign transaction failed', { order_id: orderId, error: txErr });
      return 'skipped';
    }

    // Notify driver
    if (assignedDriverId) {
      sendToDriver(assignedDriverId, 'انتهى وقت الطلب', `تم إعادة الطلب #${orderId.substring(0, 6)} للسائقين الآخرين`, {
        notificationType: 'timeout_expired',
        orderId,
        reason: 'timeout',
      }).catch(() => {});
    }

    // Notify client
    if (ownerId) {
      sendToClient(ownerId, 'جارِ البحث عن سائق آخر', 'نعتذر عن التأخير، جارِ إيجاد سائق جديد', {
        type: 'order_reassigned',
        orderId,
      }).catch(() => {});
    }

    return 'reassigned';
  }

  // ── Not yet at first reminder interval → skip ──
  if (elapsedMinutes < REMINDER_INTERVAL_MINUTES) {
    return 'skipped';
  }

  // ── Idempotency: don't re-send within same minute window ──
  const lastSentMs: number = orderData.lastReminderSentAt?.toMillis?.() || 0;
  if (lastSentMs && (nowMs - lastSentMs) < REMINDER_INTERVAL_MINUTES * 60000 * 0.9) {
    return 'skipped';
  }

  // ── Send reminder ──
  if (assignedDriverId) {
    const sent = await sendToDriver(
      assignedDriverId,
      'هل وصلت للعميل؟',
      `لديك ${remainingMinutes} دقائق لبدء الرحلة`,
      {
        notificationType: 'trip_start_reminder',
        orderId,
        pickupLabel: orderData.pickupAddress?.label || 'موقع الاستلام',
        elapsedMinutes: String(Math.floor(elapsedMinutes)),
        remainingMinutes: String(remainingMinutes),
      },
      'trip_reminders'
    );

    if (sent) {
      await orderRef.update({
        lastReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
        reminderCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => {});
    }
  }

  return 'reminded';
}

// ---------------------------------------------------------------------------
// Scheduled entry point
// ---------------------------------------------------------------------------

export const monitorAcceptedOrders = functions
  .region('us-central1')
  .runWith({ timeoutSeconds: 120, memory: '256MB' })
  .pubsub.schedule('every 1 minutes')
  .timeZone('Africa/Nouakchott')
  .onRun(async () => {
    const db = admin.firestore();
    const now = Date.now();

    console.log('[MonitorAccepted] Triggered at', new Date(now).toISOString());

    try {
      // Query accepted orders with a driver assigned
      const snapshot = await db
        .collection('orders')
        .where('status', '==', 'accepted')
        .limit(BATCH_LIMIT)
        .get();

      if (snapshot.empty) {
        console.log('[MonitorAccepted] No accepted orders to monitor.');
        return null;
      }

      console.log(`[MonitorAccepted] Found ${snapshot.size} accepted orders.`);

      let reminded = 0;
      let reassigned = 0;
      let skipped = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();

        // Safety: must still be accepted with a driver
        if (data.status !== 'accepted' || !data.assignedDriverId) {
          skipped++;
          continue;
        }

        const result = await processAcceptedOrder(doc.id, data, now);
        if (result === 'reminded') reminded++;
        else if (result === 'reassigned') reassigned++;
        else skipped++;
      }

      console.log('[MonitorAccepted] Run complete', { reminded, reassigned, skipped, total: snapshot.size });
      return null;
    } catch (error) {
      console.error('[MonitorAccepted] Fatal error:', error);
      throw new functions.https.HttpsError('internal', 'Failed to monitor accepted orders', error);
    }
  });
