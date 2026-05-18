/**
 * Cloud Function: Notify Order Events
 * 
 * Sends FCM push notifications to users when order status changes.
 * Triggers on orders/{orderId} updates.
 * 
 * Notifications sent:
 * - Client: driver_accepted, driver_on_route, trip_completed, order_expired
 * 
 * Author: WawApp Development Team
 * Last Updated: 2025-11-21
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';
import { releaseDriverState } from './dispatch/state';
import { writeAdminNotification } from './helpers/adminNotifications';

/**
 * Notification configuration
 */
interface NotificationConfig {
  title: string;
  body: string;
  type: string; // For app navigation routing
}

/**
 * Get notification content based on status transition
 */
function getNotificationConfig(
  fromStatus: string,
  toStatus: string
): NotificationConfig | null {
  // Client notifications (order owner receives these)
  if (fromStatus === 'matching' && toStatus === 'accepted') {
    return {
      title: 'تم قبول طلبك',
      body: 'قبل السائق طلبك وهو في الطريق إليك',
      type: 'driver_accepted',
    };
  }


  if (fromStatus === 'onRoute' && toStatus === 'completed') {
    return {
      title: 'اكتملت الرحلة',
      body: 'وصلت إلى وجهتك. قيّم تجربتك مع السائق',
      type: 'trip_completed',
    };
  }

  if (fromStatus === 'matching' && toStatus === 'expired') {
    return {
      title: 'انتهت مهلة الطلب',
      body: 'لم يتم العثور على سائق. جرب مرة أخرى؟',
      type: 'order_expired',
    };
  }

  // Driver notifications (notify driver when client cancels)
  if (fromStatus === 'matching' && toStatus === 'cancelledByClient') {
    return {
      title: 'تم إلغاء الطلب',
      body: 'ألغى العميل الطلب',
      type: 'order_cancelled_by_client',
    };
  }

  if (fromStatus === 'accepted' && toStatus === 'cancelledByClient') {
    return {
      title: 'ألغى العميل الرحلة',
      body: 'العميل ألغى الرحلة التي قبلتها',
      type: 'trip_cancelled_by_client',
    };
  }

  if (toStatus === 'cancelledByDriver') {
    return {
      title: 'ألغى السائق الطلب',
      body: 'السائق ألغى الطلب. جارِ البحث عن سائق آخر...',
      type: 'cancelled_by_driver',
    };
  }

  // System cancellation (e.g. insufficient driver balance after repeated attempts)
  if (toStatus === 'cancelledBySystem') {
    return {
      title: 'تم إلغاء الطلب',
      body: 'تعذّر إتمام الطلب. يرجى المحاولة مجدداً.',
      type: 'order_cancelled_by_system',
    };
  }

  // No notification needed for this transition
  return null;
}

/**
 * Send FCM notification to user
 */
async function sendNotification(
  userId: string,
  orderId: string,
  config: NotificationConfig,
  userCollection: 'users' | 'drivers' = 'users'
): Promise<boolean> {
  // Idempotency: Check if notification already sent
  const notificationId = `${userId}_${orderId}_${config.type}`;
  const notificationLogRef = admin.firestore()
    .collection('notification_log')
    .doc(notificationId);

  const alreadySent = await notificationLogRef.get();

  if (alreadySent.exists) {
    console.log('[NotifyOrderEvents] Notification already sent, skipping (idempotent)', {
      notification_id: notificationId,
      user_id: userId,
      order_id: orderId,
      type: config.type,
    });
    return true; // Already sent, consider success
  }

  // Generate deep link based on notification type
  let deepLink: string;

  switch (config.type) {
    case 'driver_accepted':
    case 'driver_on_route':
      deepLink = `/order/${orderId}/tracking`;
      break;

    case 'trip_completed':
      deepLink = `/order/${orderId}/completed`;
      break;

    case 'order_expired':
      deepLink = '/error?message=Order expired';
      break;

    case 'order_cancelled_by_client':
    case 'trip_cancelled_by_client':
    case 'cancelled_by_driver':
      deepLink = '/orders/nearby';
      break;

    case 'order_expired_driver':
      deepLink = '/orders/nearby';
      break;

    case 'order_cancelled_by_system':
      deepLink = '/';
      break;

    default:
      deepLink = '/';
  }

  try {
    // Fetch user's FCM token from Firestore
    // Clients are in 'users', drivers are in 'drivers'
    const userDoc = await admin.firestore()
      .collection(userCollection)
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      console.warn('[NotifyOrderEvents] User not found', { user_id: userId });
      return false;
    }

    const fcmToken = userDoc.data()?.fcmToken as string | undefined;

    if (!fcmToken) {
      console.log('[NotifyOrderEvents] No FCM token for user (notifications disabled)', {
        user_id: userId,
        order_id: orderId,
      });
      return false; // Not an error - user hasn't granted notification permission
    }

    // Send FCM notification (data-only for full-screen intent on Android)
    const message: admin.messaging.Message = {
      token: fcmToken,
      data: {
        orderId: orderId,
        type: config.type,
        status: config.type, // For backwards compatibility
        deepLink: deepLink, // Deep link for navigation
        title: config.title, // Move to data for native handling
        body: config.body, // Move to data for native handling
        notificationType: config.type, // For native notification handler
      },
      android: {
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: config.title,
              body: config.body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);

    console.log('[NotifyOrderEvents] Notification sent successfully', {
      user_id: userId,
      order_id: orderId,
      type: config.type,
      message_id: response,
    });

    // Mark notification as sent (idempotency log)
    await notificationLogRef.set({
      userId: userId,
      orderId: orderId,
      notificationType: config.type,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      messageId: response,
    });

    console.log('[NotifyOrderEvents] Notification logged for idempotency', {
      notification_id: notificationId,
    });

    // TODO: Add Firestore TTL rule to auto-delete notification_log docs after 7 days
    // firestore.rules: allow delete: if request.time > resource.data.sentAt + duration.value(7, 'd');

    // Log analytics event
    console.log('[Analytics] notification_sent', {
      user_id: userId,
      order_id: orderId,
      notification_type: config.type,
    });

    return true;
  } catch (error: any) {
    // Handle invalid/expired FCM tokens
    if (error.code === 'messaging/invalid-registration-token' ||
      error.code === 'messaging/registration-token-not-registered') {
      console.warn('[NotifyOrderEvents] Invalid FCM token, removing from user', {
        user_id: userId,
        error_code: error.code,
      });

      // Remove invalid token from Firestore
      await admin.firestore()
        .collection(userCollection)
        .doc(userId)
        .update({ fcmToken: admin.firestore.FieldValue.delete() });

      return false;
    }

    // Other errors
    console.error('[NotifyOrderEvents] Failed to send notification', {
      user_id: userId,
      order_id: orderId,
      error: error.message,
    });

    // Log failed notification analytics
    console.log('[Analytics] notification_failed', {
      user_id: userId,
      order_id: orderId,
      notification_type: config.type,
      error_code: error.code || 'unknown',
      error_message: error.message,
    });

    // Don't throw - we don't want to block order updates if notifications fail
    return false;
  }
}

/**
 * Cloud Function: Trigger on order updates
 */
export const notifyOrderEvents = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const orderId = context.params.orderId;

    const beforeStatus = beforeData.status as string;
    const afterStatus = afterData.status as string;

    // Only process if status changed
    if (beforeStatus === afterStatus) {
      return null;
    }

    console.log('[NotifyOrderEvents] Order status changed', {
      order_id: orderId,
      from_status: beforeStatus,
      to_status: afterStatus,
    });

    // Release driver dispatch state on trip completion (before notification check
    // so it always runs even if notificationConfig is null)
    if (afterStatus === 'completed') {
      const assignedDriverId = (afterData.assignedDriverId || afterData.driverId) as string | undefined;
      if (assignedDriverId) {
        await releaseDriverState(assignedDriverId);
      }
    }

    // Get notification config for this transition
    const notificationConfig = getNotificationConfig(beforeStatus, afterStatus);

    if (!notificationConfig) {
      console.log('[NotifyOrderEvents] No notification needed for this transition', {
        order_id: orderId,
        from_status: beforeStatus,
        to_status: afterStatus,
      });
      return null;
    }

    // Send notification to order owner (client)
    const ownerId = afterData.ownerId as string;
    if (!ownerId) {
      console.warn('[NotifyOrderEvents] Order has no ownerId', { order_id: orderId });
      return null;
    }

    await sendNotification(ownerId, orderId, notificationConfig, 'users');

    // Release driver dispatch state when driver cancels
    if (afterStatus === 'cancelledByDriver') {
      const driverId = (afterData.assignedDriverId || afterData.driverId) as string | undefined;
      if (driverId) {
        await releaseDriverState(driverId);
        console.log('[NotifyOrderEvents] Released driver state after driver cancellation', {
          order_id: orderId,
          driver_id: driverId,
        });
      }
    }

    // STEP 3A: Notify assigned driver if client cancelled
    if ((beforeStatus === 'accepted' || beforeStatus === 'onRoute') &&
      afterStatus === 'cancelledByClient') {
      const assignedDriverId = afterData.assignedDriverId as string | undefined;

      if (assignedDriverId) {
        console.log('[NotifyOrderEvents] Notifying assigned driver of cancellation', {
          order_id: orderId,
          driver_id: assignedDriverId,
        });

        const driverNotificationConfig = getNotificationConfig(beforeStatus, afterStatus);
        if (driverNotificationConfig) {
          await sendNotification(assignedDriverId, orderId, driverNotificationConfig, 'drivers');
        }

        // Release driver dispatch state so they can receive new offers
        await releaseDriverState(assignedDriverId);
      }

      // Clean up dispatch_offers for this cancelled order
      const offersSnap = await admin.firestore()
        .collection('dispatch_offers')
        .where('orderId', '==', orderId)
        .get();
      if (!offersSnap.empty) {
        const batch = admin.firestore().batch();
        offersSnap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        console.log('[NotifyOrderEvents] Deleted dispatch_offers for cancelled order', {
          order_id: orderId,
          deleted_count: offersSnap.size,
        });
      }
    }

    // STEP 3B: Clean up dispatch when client cancels from 'matching' state
    // (order was never accepted — just cancel all pending offers and dequeue)
    if (beforeStatus === 'matching' && afterStatus === 'cancelledByClient') {
      // Cancel all pending dispatch_offers
      const offersSnap = await admin.firestore()
        .collection('dispatch_offers')
        .where('orderId', '==', orderId)
        .where('status', '==', 'sent')
        .get();
      if (!offersSnap.empty) {
        const batch = admin.firestore().batch();
        offersSnap.docs.forEach((doc) => {
          batch.update(doc.ref, {
            status: 'cancelled',
            respondedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        await batch.commit();
        console.log('[NotifyOrderEvents] Cancelled dispatch_offers for client-cancelled matching order', {
          order_id: orderId,
          cancelled_count: offersSnap.size,
        });
      }

      // Remove from dispatch_queue
      await admin.firestore().collection('dispatch_queue').doc(orderId).delete().catch(() => { });
      console.log('[NotifyOrderEvents] Dequeued client-cancelled order from dispatch_queue', {
        order_id: orderId,
      });
    }

    // Write admin notification for expired orders
    if (afterStatus === 'expired') {
      await writeAdminNotification({
        type: 'expired_order',
        title: 'طلب منتهي الصلاحية',
        body: `طلب #${orderId.substring(0, 6)} انتهت مهلته دون إسناد سائق`,
        data: { orderId, ownerId },
      });
    }

    return null;
  });
