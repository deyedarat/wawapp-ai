/**
 * WawApp Dispatch Engine — FCM Notifications
 *
 * Sends push notifications for dispatch offers.
 *
 * @author WawApp Development Team
 * @version 2.0.0
 */

import * as admin from 'firebase-admin';
import { DispatchOffer, NotificationData } from './types';

// ============================================================================
// FCM NOTIFICATION SENDER
// ============================================================================

/**
 * Send offer notification to driver
 *
 * @param offer Dispatch offer document
 * @param orderData Order data from Firestore
 * @param fcmToken Driver FCM token
 * @returns Result with success status and message ID
 */
export async function sendOfferNotification(
  offer: DispatchOffer,
  orderData: any,
  fcmToken: string
): Promise<{ success: boolean; messageId?: string; error?: string }> {
  try {
    // Resolve pickup/dropoff labels (support both formats)
    const pickupLabel =
      orderData.pickup?.label ||
      (typeof orderData.pickupAddress === 'string'
        ? orderData.pickupAddress
        : orderData.pickupAddress?.label) ||
      'موقع الانطلاق';

    const dropoffLabel =
      orderData.dropoff?.label ||
      (typeof orderData.dropoffAddress === 'string'
        ? orderData.dropoffAddress
        : orderData.dropoffAddress?.label) ||
      'الوجهة';

    // Resolve coordinates
    const pLat = orderData.pickup?.lat || orderData.pickupAddress?.latitude || 0;
    const pLng = orderData.pickup?.lng || orderData.pickupAddress?.longitude || 0;
    const dLat = orderData.dropoff?.lat || orderData.dropoffAddress?.latitude || 0;
    const dLng = orderData.dropoff?.lng || orderData.dropoffAddress?.longitude || 0;

    // Build notification data payload
    const notificationData: NotificationData = {
      messageId: `${offer.orderId}_wave_offer_${offer.round}_${Date.now()}`,
      notificationType: offer.round === 1 ? 'new_order' : 'wave_offer',
      type: offer.round === 1 ? 'new_order' : 'wave_offer',

      orderId: offer.orderId,
      offerId: offer.offerId,

      title: offer.round === 1 ? 'طلب جديد قريب منك' : `طلب قريب منك (جولة ${offer.round})`,
      body: `${pickupLabel} → ${dropoffLabel}`,

      pickupLabel,
      dropoffLabel,

      pickupLat: String(pLat),
      pickupLng: String(pLng),
      dropoffLat: String(dLat),
      dropoffLng: String(dLng),

      price: String(orderData.price || 0),
      distance: String(offer.distance.toFixed(2)),
      clientName: orderData.clientName || 'عميل',

      createdAt: String(orderData.createdAt?.toMillis() || Date.now()),
      expiresAt: String(offer.expiresAt.toMillis()),
      round: String(offer.round),
    };

    // Build FCM message
    const message: admin.messaging.Message = {
      token: fcmToken,
      data: notificationData as unknown as Record<string, string>,
      android: {
        priority: 'high',
        ttl: (offer.expiresAt.toMillis() - Date.now()), // TTL = time until offer expires
        collapseKey: `order_${offer.orderId}`,
      },
      apns: {
        payload: {
          aps: {
            sound: 'trip_reminder.wav',
            badge: 1,
            contentAvailable: true,
          },
        },
      },
    };

    // Send FCM
    const messageId = await admin.messaging().send(message);

    console.log('[DispatchNotifications] Notification sent', {
      offer_id: offer.offerId,
      driver_id: offer.driverId,
      order_id: offer.orderId,
      wave: offer.round,
      message_id: messageId,
    });

    return { success: true, messageId };
  } catch (error: any) {
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

    // Log other errors
    console.error('[DispatchNotifications] Failed to send notification', {
      offer_id: offer.offerId,
      driver_id: offer.driverId,
      error_code: error.code || 'unknown',
      error_message: error.message,
    });

    return { success: false, error: error.code || 'unknown' };
  }
}
