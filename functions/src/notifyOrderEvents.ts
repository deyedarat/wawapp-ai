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

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Notification configuration
 */
interface NotificationConfig {
  title: string;
  body: string;
  type: string; // For app navigation routing
}

/**
 * Generates a Firebase Dynamic Link for notification deep linking
 * @param domain - Dynamic Links domain (e.g., 'wawappclient.page.link')
 * @param deepLinkPath - Path to navigate to (e.g., '/order/123/tracking')
 * @returns The generated dynamic link URL
 */
function generateDynamicLink(
  domain: string,
  deepLinkPath: string
): string {
  try {
    // Return the full dynamic link URL
    // Firebase Dynamic Links will handle redirection via AndroidManifest intent-filters
    const deepLink = `https://${domain}${deepLinkPath}`;
    return deepLink;
  } catch (error) {
    console.error('[Dynamic Link] Generation failed:', error);
    // Fallback to basic deep link
    return `https://${domain}${deepLinkPath}`;
  }
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

  if (fromStatus === 'accepted' && toStatus === 'onRoute') {
    return {
      title: 'السائق في الطريق',
      body: 'السائق الآن في طريقه لموقع الانطلاق',
      type: 'driver_on_route',
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

  // No notification needed for this transition
  return null;
}

/**
 * Send FCM notification to user
 */
async function sendNotification(
  userId: string,
  orderId: string,
  config: NotificationConfig
): Promise<boolean> {
  // Generate deep link based on notification type
  let deepLink: string;
  
  switch (config.type) {
    case 'driver_accepted':
    case 'driver_on_route':
      deepLink = generateDynamicLink(
        'wawappclient.page.link',
        `/order/${orderId}/tracking`
      );
      break;
    
    case 'trip_completed':
      deepLink = generateDynamicLink(
        'wawappclient.page.link',
        `/order/${orderId}/completed`
      );
      break;
    
    case 'order_expired':
      deepLink = generateDynamicLink(
        'wawappclient.page.link',
        '/error?message=Order expired'
      );
      break;
    
    default:
      deepLink = generateDynamicLink(
        'wawappclient.page.link',
        '/'
      );
  }
  
  console.log(`[Dynamic Link] Generated for ${config.type}: ${deepLink}`);
  try {
    // Fetch user's FCM token from Firestore
    const userDoc = await admin.firestore()
      .collection('users')
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

    // Send FCM notification
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: config.title,
        body: config.body,
      },
      data: {
        orderId: orderId,
        type: config.type,
        status: config.type, // For backwards compatibility
        deepLink: deepLink, // Deep link for navigation
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'order_updates', // Must match Android channel in app
        },
      },
      apns: {
        payload: {
          aps: {
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
        .collection('users')
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

    await sendNotification(ownerId, orderId, notificationConfig);

    return null;
  });
