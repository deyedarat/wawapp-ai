/**
 * Cloud Function: Monitor Accepted Orders (Phase D — Enhanced v2)
 *
 * Sends escalating trip-start reminders to drivers after acceptance.
 * NO automatic cancellation — order stays with driver indefinitely.
 *
 * Escalation levels:
 *   0-6 min  → Normal reminder (with extension option)
 *   6-15 min → Warning (delay recorded)
 *   15+ min  → Critical alert (admin notified + violation logged)
 *
 * Reminders sent every 3 minutes. Runs every 1 minute via Cloud Scheduler.
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { writeAdminNotification } from './helpers/adminNotifications';

// Constants
const REMINDER_INTERVAL_MINUTES = 3;
const WARNING_THRESHOLD_MINUTES = 6;
const CRITICAL_THRESHOLD_MINUTES = 15;
const BATCH_LIMIT = 50;

type EscalationLevel = 'normal' | 'warning' | 'critical';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getEscalationLevel(elapsedMinutes: number): EscalationLevel {
  if (elapsedMinutes >= CRITICAL_THRESHOLD_MINUTES) return 'critical';
  if (elapsedMinutes >= WARNING_THRESHOLD_MINUTES) return 'warning';
  return 'normal';
}

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
      notification: {
        title,
        body,
      },
      data: {
        ...data,
        title,
        body,
        channelId,
        notificationType: data.notificationType || data.type || '',
      },
      android: {
        priority: 'high',
        ttl: 120000,
        notification: {
          channelId,
          sound: 'trip_reminder',
        },
      },
      apns: { payload: { aps: { sound: 'trip_reminder.wav', badge: 1, contentAvailable: true } } },
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

function formatAddress(addr: any): string {
  if (!addr) return 'غير محدد';
  if (typeof addr === 'string') return addr;
  return addr.label || addr.address || addr.name || 'غير محدد';
}

function buildNotification(
  level: EscalationLevel,
  elapsedMinutes: number,
  orderData: FirebaseFirestore.DocumentData,
  orderId: string
): { title: string; body: string } {
  const customerName = orderData.clientName || orderData.ownerName || 'العميل';
  const pickup = formatAddress(orderData.pickupAddress);
  const destination = formatAddress(orderData.destinationAddress || orderData.dropoffAddress);
  const elapsed = Math.floor(elapsedMinutes);

  switch (level) {
    case 'normal':
      return {
        title: `تذكير بالرحلة - ${customerName}`,
        body: `📍 الاستلام: ${pickup}\n🎯 الوجهة: ${destination}\n⏱️ منذ القبول: ${elapsed} دقائق\n\nهل وصلت للعميل؟`,
      };
    case 'warning':
      return {
        title: `⚠️ تأخير - ${customerName}`,
        body: `📍 ${pickup} → ${destination}\n⏱️ ${elapsed} دقائق منذ القبول\n\n⚠️ يرجى الوصول فوراً. تم تسجيل التأخير.`,
      };
    case 'critical':
      return {
        title: `🚨 تحذير نهائي - ${customerName}`,
        body: `📍 ${pickup} → ${destination}\n⏱️ ${elapsed} دقائق منذ القبول\n\n🚨 تم إبلاغ الإدارة. يرجى بدء الرحلة الآن!`,
      };
  }
}

// ---------------------------------------------------------------------------
// Violation & admin alert helpers (idempotent)
// ---------------------------------------------------------------------------

async function logViolation(
  db: FirebaseFirestore.Firestore,
  driverId: string,
  orderId: string,
  delayMinutes: number,
  extensionsUsed: number
): Promise<void> {
  const violationId = `excessive_delay_${orderId}`;
  const ref = db.collection('drivers').doc(driverId).collection('violations').doc(violationId);
  const existing = await ref.get();
  if (existing.exists) return; // idempotent

  await ref.set({
    type: 'excessive_delay_accepted',
    orderId,
    driverId,
    delayMinutes: Math.floor(delayMinutes),
    extensionsUsed,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('[MonitorAccepted] Violation logged', { driver_id: driverId, order_id: orderId });
}

async function notifyAdminCriticalDelay(
  orderData: FirebaseFirestore.DocumentData,
  orderId: string,
  driverId: string,
  delayMinutes: number
): Promise<void> {
  const driverName = orderData.driverName || driverId.substring(0, 8);
  const customerName = orderData.clientName || orderData.ownerName || 'عميل';
  const pickup = formatAddress(orderData.pickupAddress);

  await writeAdminNotification({
    type: 'critical_delay',
    title: `🚨 تأخير حرج - سائق ${driverName}`,
    body: `الطلب #${orderId.substring(0, 6)} متأخر ${Math.floor(delayMinutes)} دقيقة.\nالعميل: ${customerName}\nالاستلام: ${pickup}`,
    data: {
      orderId,
      driverId,
      delayMinutes: String(Math.floor(delayMinutes)),
      customerName,
    },
  });
}

// ---------------------------------------------------------------------------
// Core: process a single accepted order
// ---------------------------------------------------------------------------

async function processAcceptedOrder(
  orderId: string,
  orderData: FirebaseFirestore.DocumentData,
  nowMs: number
): Promise<'reminded' | 'skipped'> {
  const db = admin.firestore();
  const orderRef = db.collection('orders').doc(orderId);

  const acceptedAtMs: number = orderData.acceptedAt?.toMillis?.() || 0;
  if (!acceptedAtMs) {
    console.warn('[MonitorAccepted] Missing acceptedAt', { order_id: orderId });
    return 'skipped';
  }

  const elapsedMs = nowMs - acceptedAtMs;
  const elapsedMinutes = elapsedMs / 60000;
  const assignedDriverId: string = orderData.assignedDriverId || orderData.driverId;

  // ── Not yet at first reminder interval → skip ──
  if (elapsedMinutes < REMINDER_INTERVAL_MINUTES) {
    return 'skipped';
  }

  // ── Idempotency: don't re-send within same interval ──
  const lastSentMs: number = orderData.lastReminderSentAt?.toMillis?.() || 0;
  if (lastSentMs && (nowMs - lastSentMs) < REMINDER_INTERVAL_MINUTES * 60000 * 0.9) {
    return 'skipped';
  }

  const level = getEscalationLevel(elapsedMinutes);
  const { title, body } = buildNotification(level, elapsedMinutes, orderData, orderId);

  // ── Send reminder to driver ──
  if (assignedDriverId) {
    const extensionsUsed: number = orderData.extensionRequestCount || 0;

    const sent = await sendToDriver(
      assignedDriverId,
      title,
      body,
      {
        notificationType: 'trip_start_reminder',
        orderId,
        escalationLevel: level,
        pickupLabel: formatAddress(orderData.pickupAddress),
        destinationLabel: formatAddress(orderData.destinationAddress || orderData.dropoffAddress),
        elapsedMinutes: String(Math.floor(elapsedMinutes)),
      },
      'trip_reminders'
    );

    if (sent) {
      const updatePayload: Record<string, any> = {
        lastReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
        reminderCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Log delay warning in order document
      if (level === 'warning' || level === 'critical') {
        updatePayload.delayWarnings = admin.firestore.FieldValue.arrayUnion({
          level,
          sentAt: new Date(nowMs),
        });
      }

      await orderRef.update(updatePayload).catch(() => {});
    }

    // ── Critical threshold: admin notification + violation (once) ──
    if (level === 'critical') {
      const alreadyNotifiedAdmin: boolean = orderData.adminNotifiedAt != null;
      if (!alreadyNotifiedAdmin) {
        await notifyAdminCriticalDelay(orderData, orderId, assignedDriverId, elapsedMinutes);
        await orderRef.update({
          adminNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => {});
      }

      await logViolation(db, assignedDriverId, orderId, elapsedMinutes, extensionsUsed);
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
      let skipped = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();
        if (data.status !== 'accepted' || !data.assignedDriverId) {
          skipped++;
          continue;
        }

        const result = await processAcceptedOrder(doc.id, data, now);
        if (result === 'reminded') reminded++;
        else skipped++;
      }

      console.log('[MonitorAccepted] Run complete', { reminded, skipped, total: snapshot.size });
      return null;
    } catch (error) {
      console.error('[MonitorAccepted] Fatal error:', error);
      throw new functions.https.HttpsError('internal', 'Failed to monitor accepted orders', error);
    }
  });
