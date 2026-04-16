/**
 * WawApp Dispatch Engine — FCM Notifications
 *
 * Sends push notifications for dispatch offers.
 *
 * ARCHITECTURE RULE:
 * After an order is enqueued, dispatch systems MUST NOT depend on raw order documents.
 * All notification data comes from dispatch_queue (normalized) — never from orders collection.
 *
 * @author WawApp Development Team
 * @version 3.0.0
 */

import * as admin from 'firebase-admin';
import { DispatchOffer, DispatchQueueEntry, NotificationData } from './types';
import { emitMetric } from './counters';

// ============================================================================
// NORMALIZED PAYLOAD ASSERTION
// ============================================================================

/**
 * Assert that a payload comes from the normalized dispatch_queue,
 * not from a raw order document.
 *
 * Detects raw order shape by checking for fields that exist on raw orders
 * but NOT on DispatchQueueEntry (e.g., `status`, `assignedDriverId`, `pickup`).
 */
export function assertNormalizedPayload(source: Record<string, any>): void {
  const RAW_ORDER_MARKERS = ['status', 'assignedDriverId', 'pickup', 'dropoff'];
  const rawFields = RAW_ORDER_MARKERS.filter((f) => f in source);
  if (rawFields.length > 0) {
    const msg = `[ARCHITECTURE VIOLATION] Raw order data passed to notification layer. ` +
      `Detected raw fields: [${rawFields.join(', ')}]. ` +
      `Use dispatch_queue entry instead.`;
    console.error(msg);
    throw new Error(msg);
  }
}

// ============================================================================
// FCM NOTIFICATION SENDER
// ============================================================================

/**
 * Send offer notification to driver.
 *
 * NEVER THROWS — always returns structured result.
 * Sources ALL data from normalized DispatchQueueEntry — never raw order.
 *
 * @param offer Dispatch offer document
 * @param queueEntry Normalized queue entry (single source of truth)
 * @param fcmToken Driver FCM token
 * @returns Structured result — always { success, messageId?, error? }
 */
export async function sendOfferNotification(
  offer: DispatchOffer,
  queueEntry: DispatchQueueEntry,
  fcmToken: string
): Promise<{ success: boolean; messageId?: string; error?: string }> {
  try {
    // Guard: reject if raw order shape leaked in
    assertNormalizedPayload(queueEntry as unknown as Record<string, any>);

    // Guard: validate required fields from queue entry
    if (!queueEntry.orderId || !Number.isFinite(queueEntry.pickupLat) || !Number.isFinite(queueEntry.pickupLng)) {
      emitMetric('notification_failed', { orderId: offer.orderId, driverId: offer.driverId, errorCode: 'missing_queue_fields' });
      console.error(JSON.stringify({
        tag: 'DispatchNotifications',
        stage: 'send',
        offerId: offer.offerId,
        driverId: offer.driverId,
        result: 'skipped_missing_queue_fields',
        hasOrderId: !!queueEntry.orderId,
        hasPickupLat: Number.isFinite(queueEntry.pickupLat),
        hasPickupLng: Number.isFinite(queueEntry.pickupLng),
      }));
      return { success: false, error: 'missing_queue_fields' };
    }

    // Guard: validate fcmToken
    if (!fcmToken || typeof fcmToken !== 'string') {
      emitMetric('notification_failed', { orderId: offer.orderId, driverId: offer.driverId, errorCode: 'missing_fcm_token' });
      return { success: false, error: 'missing_fcm_token' };
    }

    // All fields sourced from normalized queue entry
    const pickupLabel = queueEntry.pickupLabel || 'موقع الانطلاق';
    const dropoffLabel = queueEntry.dropoffLabel || 'الوجهة';
    const price = Number.isFinite(queueEntry.price) ? queueEntry.price : 0;
    const clientName = queueEntry.clientName || 'عميل';
    const createdAtMs = queueEntry.createdAt?.toMillis?.() ?? Date.now();
    const expiresAtMs = offer.expiresAt?.toMillis?.() ?? Date.now();
    const distance = Number.isFinite(offer.distance) ? offer.distance : 0;

    const notificationData: NotificationData = {
      messageId: `${offer.orderId}_wave_offer_${offer.round}_${Date.now()}`,
      notificationType: offer.round === 1 ? 'new_order' : 'wave_offer',
      type: offer.round === 1 ? 'new_order' : 'wave_offer',

      orderId: offer.orderId || '',
      offerId: offer.offerId || '',

      title: offer.round === 1 ? 'طلب جديد قريب منك' : `طلب قريب منك (جولة ${offer.round})`,
      body: `${pickupLabel} → ${dropoffLabel}`,

      pickupLabel,
      dropoffLabel,

      pickupLat: String(queueEntry.pickupLat),
      pickupLng: String(queueEntry.pickupLng),
      dropoffLat: String(Number.isFinite(queueEntry.dropoffLat) ? queueEntry.dropoffLat : 0),
      dropoffLng: String(Number.isFinite(queueEntry.dropoffLng) ? queueEntry.dropoffLng : 0),

      price: String(price),
      distance: String(distance.toFixed(2)),
      clientName,

      createdAt: String(createdAtMs),
      expiresAt: String(expiresAtMs),
      round: String(offer.round ?? 1),
    };

    // Build FCM message — guard TTL against negative values
    const ttlMs = Math.max(0, expiresAtMs - Date.now());
    const title = notificationData.title;
    const body = notificationData.body;
    const message: admin.messaging.Message = {
      token: fcmToken,
      // notification block ensures Android system tray display when app is killed.
      // When app is alive, MyFirebaseMessagingService intercepts before system tray
      // and routes to Flutter — so this block is only visible in killed state.
      notification: {
        title,
        body,
      },
      data: notificationData as unknown as Record<string, string>,
      android: {
        priority: 'high',
        ttl: ttlMs,
        collapseKey: `order_${offer.orderId}`,
        notification: {
          channelId: 'new_orders_v9',
          sound: 'trip_reminder',
          priority: 'max',
          defaultVibrateTimings: false,
          vibrateTimingsMillis: [0, 500, 200, 500, 200, 500],
          visibility: 'public',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'trip_reminder.wav',
            badge: 1,
            contentAvailable: true,
            alert: { title, body },
          },
        },
      },
    };

    const messageId = await admin.messaging().send(message);
    emitMetric('notification_sent', { orderId: offer.orderId, driverId: offer.driverId, wave: offer.round });

    console.log('[DispatchNotifications] Notification sent', {
      offer_id: offer.offerId,
      driver_id: offer.driverId,
      order_id: offer.orderId,
      wave: offer.round,
      message_id: messageId,
    });

    return { success: true, messageId };
  } catch (error: any) {
    // NEVER THROW — always return structured result

    // Handle invalid/expired FCM tokens
    if (
      error.code === 'messaging/invalid-registration-token' ||
      error.code === 'messaging/registration-token-not-registered'
    ) {
      console.warn('[DispatchNotifications] Invalid FCM token', {
        driver_id: offer.driverId,
        error_code: error.code,
      });

      // Remove invalid token (non-blocking)
      admin
        .firestore()
        .collection('drivers')
        .doc(offer.driverId)
        .update({ fcmToken: admin.firestore.FieldValue.delete() })
        .catch((err) =>
          console.error('[DispatchNotifications] Failed to remove invalid token', err)
        );

      return { success: false, error: 'invalid_token' };
    }

    emitMetric('notification_failed', { orderId: offer.orderId, driverId: offer.driverId, errorCode: error.code || error.message || 'unknown' });

    console.error('[DispatchNotifications] Failed to send notification', {
      offer_id: offer.offerId,
      driver_id: offer.driverId,
      error_code: error.code || 'unknown',
      error_message: error.message,
    });

    return { success: false, error: error.code || error.message || 'unknown' };
  }
}
