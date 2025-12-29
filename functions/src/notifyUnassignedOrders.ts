/**
 * Cloud Function: Notify Drivers of Unassigned Orders
 * 
 * Phase A: Sends repeated FCM notifications to eligible drivers every 60 seconds
 * for orders that remain unassigned (status in [requested, assigning/matching] AND assignedDriverId == null).
 * 
 * Rules:
 * - Unassigned = status in [requested, assigning, matching] AND assignedDriverId == null
 * - Stop immediately when: status in [accepted, onRoute, completed, cancelledByClient, cancelledByDriver, expired] OR assignedDriverId != null
 * - Max notifications per (driver, order): 10 total
 * - Deduplication required (no duplicate pushes on retries)
 * 
 * Runs every 1 minute via Cloud Scheduler.
 * 
 * Author: WawApp Development Team (Phase A Implementation)
 * Last Updated: 2025-12-28
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Constants
const MAX_NOTIFICATION_RADIUS_KM = 10; // Maximum radius to search for drivers
const MAX_DRIVERS_TO_NOTIFY = 20; // Limit concurrent notifications
const MIN_DRIVER_ACCURACY_METERS = 100; // Filter out inaccurate location data
const MAX_NOTIFICATIONS_PER_DRIVER_ORDER = 10; // Max notifications per (driver, order) pair
const BATCH_LIMIT = 100; // Max unassigned orders to process per run

/**
 * Haversine distance calculation (in kilometers)
 */
function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Interface for eligible driver with location
 */
interface EligibleDriver {
  driverId: string;
  distance: number;
  fcmToken?: string;
  isOnline: boolean;
}

/**
 * Find eligible drivers near pickup location
 */
async function findEligibleDrivers(
  pickupLat: number,
  pickupLng: number
): Promise<EligibleDriver[]> {
  const eligibleDrivers: EligibleDriver[] = [];

  try {
    // Query driver_locations collection for recent, accurate locations
    const locationsSnapshot = await admin
      .firestore()
      .collection('driver_locations')
      .where('updatedAt', '>', new Date(Date.now() - 5 * 60 * 1000)) // Last 5 minutes
      .get();

    if (locationsSnapshot.empty) {
      return [];
    }

    // Process each driver location
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const driverId = locationDoc.id;

      // Support both field name formats: lat/lng (driver app) and latitude/longitude (legacy)
      const driverLat = locationData.latitude || locationData.lat;
      const driverLng = locationData.longitude || locationData.lng;

      // Skip if location data is incomplete or inaccurate
      if (
        !driverLat ||
        !driverLng ||
        (locationData.accuracy && locationData.accuracy > MIN_DRIVER_ACCURACY_METERS)
      ) {
        continue;
      }

      // Calculate distance from pickup location
      const distance = calculateDistance(
        pickupLat,
        pickupLng,
        driverLat,
        driverLng
      );

      // Skip if driver is too far
      if (distance > MAX_NOTIFICATION_RADIUS_KM) {
        continue;
      }

      // Fetch driver profile to check online/available status and FCM token
      const driverDoc = await admin
        .firestore()
        .collection('drivers')
        .doc(driverId)
        .get();

      if (!driverDoc.exists) {
        continue;
      }

      const driverData = driverDoc.data();

      // Check if driver is online
      const isOnline = driverData?.isOnline === true;

      // Only notify online drivers
      if (!isOnline) {
        continue;
      }

      eligibleDrivers.push({
        driverId,
        distance,
        fcmToken: driverData?.fcmToken as string | undefined,
        isOnline,
      });
    }

    // Sort by distance (closest first) and limit
    eligibleDrivers.sort((a, b) => a.distance - b.distance);
    return eligibleDrivers.slice(0, MAX_DRIVERS_TO_NOTIFY);
  } catch (error: any) {
    console.error('[NotifyUnassignedOrders] Error finding eligible drivers:', {
      error: error.message,
      pickup_lat: pickupLat,
      pickup_lng: pickupLng,
    });
    return [];
  }
}

/**
 * Check if driver has reached notification limit for this order
 */
async function hasReachedNotificationLimit(
  driverId: string,
  orderId: string
): Promise<boolean> {
  try {
    const notificationCountDoc = await admin
      .firestore()
      .collection('driver_order_notifications')
      .doc(`${driverId}_${orderId}`)
      .get();

    if (!notificationCountDoc.exists) {
      return false;
    }

    const data = notificationCountDoc.data();
    return (data?.count || 0) >= MAX_NOTIFICATIONS_PER_DRIVER_ORDER;
  } catch (error) {
    console.error('[NotifyUnassignedOrders] Error checking notification limit:', error);
    return false; // Allow notification on error
  }
}

/**
 * Increment notification count for driver-order pair
 */
async function incrementNotificationCount(
  driverId: string,
  orderId: string
): Promise<void> {
  try {
    const docRef = admin
      .firestore()
      .collection('driver_order_notifications')
      .doc(`${driverId}_${orderId}`);

    await docRef.set({
      driverId,
      orderId,
      count: admin.firestore.FieldValue.increment(1),
      lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (error) {
    console.error('[NotifyUnassignedOrders] Error incrementing notification count:', error);
    // Don't throw - notification failure shouldn't block the process
  }
}

/**
 * Send FCM notification to driver with deduplication
 */
async function sendDriverNotification(
  driver: EligibleDriver,
  orderId: string,
  orderData: any
): Promise<{ success: boolean; error?: string }> {
  if (!driver.fcmToken) {
    return {
      success: false,
      error: 'no_fcm_token',
    };
  }

  // Check notification limit
  const hasReachedLimit = await hasReachedNotificationLimit(driver.driverId, orderId);
  if (hasReachedLimit) {
    return {
      success: false,
      error: 'notification_limit_reached',
    };
  }

  try {
    // Prepare notification data payload
    const message: admin.messaging.Message = {
      token: driver.fcmToken,
      notification: {
        title: 'طلب متاح قريب منك',
        body: `${orderData.pickupAddress?.label || 'موقع الانطلاق'} → ${
          orderData.dropoffAddress?.label || 'الوجهة'
        }`,
      },
      data: {
        notificationType: 'unassigned_order_reminder',
        orderId: orderId,
        pickupLat: String(orderData.pickupAddress?.latitude || 0),
        pickupLng: String(orderData.pickupAddress?.longitude || 0),
        dropoffLat: String(orderData.dropoffAddress?.latitude || 0),
        dropoffLng: String(orderData.dropoffAddress?.longitude || 0),
        clientName: orderData.clientName || 'عميل',
        createdAt: String(orderData.createdAt?.toMillis() || Date.now()),
        distance: String(driver.distance.toFixed(2)),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'unassigned_orders', // Must match Android channel in driver app
          priority: 'high',
          visibility: 'public',
        },
        ttl: 300000, // 5 minutes TTL
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            contentAvailable: true,
          },
        },
      },
    };

    // Send with automatic retry (Firebase SDK handles this)
    const response = await admin.messaging().send(message);

    // Increment notification count for this driver-order pair
    await incrementNotificationCount(driver.driverId, orderId);

    console.log('[NotifyUnassignedOrders] Notification sent to driver', {
      driver_id: driver.driverId,
      order_id: orderId,
      distance_km: driver.distance.toFixed(2),
      message_id: response,
    });

    return { success: true };
  } catch (error: any) {
    // Handle invalid/expired FCM tokens
    if (
      error.code === 'messaging/invalid-registration-token' ||
      error.code === 'messaging/registration-token-not-registered'
    ) {
      console.warn('[NotifyUnassignedOrders] Invalid FCM token, removing from driver', {
        driver_id: driver.driverId,
        error_code: error.code,
      });

      // Remove invalid token (non-blocking)
      admin
        .firestore()
        .collection('drivers')
        .doc(driver.driverId)
        .update({ fcmToken: admin.firestore.FieldValue.delete() })
        .catch((err) =>
          console.error('[NotifyUnassignedOrders] Failed to remove invalid token:', err)
        );

      return {
        success: false,
        error: 'invalid_token',
      };
    }

    // Log other errors but don't fail
    console.error('[NotifyUnassignedOrders] Failed to send notification to driver', {
      driver_id: driver.driverId,
      order_id: orderId,
      error_code: error.code || 'unknown',
      error_message: error.message,
    });

    return {
      success: false,
      error: error.code || 'unknown',
    };
  }
}

/**
 * Process a single unassigned order
 */
async function processUnassignedOrder(orderId: string, orderData: any): Promise<void> {
  // Validate pickup location - support both formats
  const pickupLat = orderData.pickupAddress?.latitude || orderData.pickup?.lat;
  const pickupLng = orderData.pickupAddress?.longitude || orderData.pickup?.lng;
  
  if (!pickupLat || !pickupLng) {
    console.warn('[NotifyUnassignedOrders] Order missing pickup coordinates', {
      order_id: orderId,
      pickup_address: orderData.pickupAddress,
      pickup: orderData.pickup,
    });
    return;
  }

  // Find eligible drivers near pickup location
  const eligibleDrivers = await findEligibleDrivers(pickupLat, pickupLng);

  if (eligibleDrivers.length === 0) {
    console.log('[NotifyUnassignedOrders] No eligible drivers found', {
      order_id: orderId,
      pickup_lat: pickupLat,
      pickup_lng: pickupLng,
    });
    return;
  }

  console.log('[NotifyUnassignedOrders] Found eligible drivers', {
    order_id: orderId,
    driver_count: eligibleDrivers.length,
    closest_distance_km: eligibleDrivers[0].distance.toFixed(2),
  });

  // Send notifications to all eligible drivers (in parallel for speed)
  const notificationPromises = eligibleDrivers.map((driver) =>
    sendDriverNotification(driver, orderId, orderData)
  );

  const results = await Promise.allSettled(notificationPromises);

  // Aggregate results
  let sentCount = 0;
  let failedCount = 0;
  const failureReasons: { [key: string]: number } = {};

  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      if (result.value.success) {
        sentCount++;
      } else {
        failedCount++;
        const reason = result.value.error || 'unknown';
        failureReasons[reason] = (failureReasons[reason] || 0) + 1;
      }
    } else {
      failedCount++;
      failureReasons['promise_rejected'] =
        (failureReasons['promise_rejected'] || 0) + 1;
    }
  });

  // Log final summary
  console.log('[NotifyUnassignedOrders] Notification summary', {
    order_id: orderId,
    candidate_drivers: eligibleDrivers.length,
    sent_count: sentCount,
    failed_count: failedCount,
    failure_reasons: JSON.stringify(failureReasons),
  });
}

/**
 * Scheduled function that notifies drivers of unassigned orders
 * Runs every 1 minute via Cloud Scheduler
 */
export const notifyUnassignedOrders = functions
  .region('us-central1')
  .runWith({
    timeoutSeconds: 300, // 5 minutes max execution time
    memory: '512MB',
  })
  .pubsub
  .schedule('every 1 minutes')
  .timeZone('Africa/Nouakchott') // Mauritania timezone
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    console.log('[NotifyUnassignedOrders] Function triggered at:', now.toDate().toISOString());

    try {
      // Query for unassigned orders:
      // - status in ['requested', 'assigning', 'matching'] (unassigned states)
      // - assignedDriverId == null (no driver has claimed it)
      const unassignedOrdersSnapshot = await db
        .collection('orders')
        .where('status', 'in', ['requested', 'assigning', 'matching'])
        .where('assignedDriverId', '==', null)
        .limit(BATCH_LIMIT)
        .get();

      if (unassignedOrdersSnapshot.empty) {
        console.log('[NotifyUnassignedOrders] No unassigned orders found.');
        return null;
      }

      console.log(`[NotifyUnassignedOrders] Found ${unassignedOrdersSnapshot.size} unassigned orders to process.`);

      let processedCount = 0;
      let skippedCount = 0;

      // Process each unassigned order
      for (const doc of unassignedOrdersSnapshot.docs) {
        const orderData = doc.data();
        const orderId = doc.id;

        // Safety check: double-verify order is still unassigned
        if (
          ['requested', 'assigning', 'matching'].includes(orderData.status) &&
          orderData.assignedDriverId === null
        ) {
          console.log('[NotifyUnassignedOrders] Processing unassigned order', {
            order_id: orderId,
            status: orderData.status,
            created_at: orderData.createdAt?.toDate?.()?.toISOString() || 'unknown',
            age_minutes: Math.floor((now.seconds - (orderData.createdAt?.seconds || now.seconds)) / 60),
          });

          await processUnassignedOrder(orderId, orderData);
          processedCount++;
        } else {
          console.log('[NotifyUnassignedOrders] Skipping order (race condition avoided)', {
            order_id: orderId,
            current_status: orderData.status,
            has_driver: orderData.assignedDriverId !== null,
          });
          skippedCount++;
        }
      }

      console.log('[NotifyUnassignedOrders] Processing completed', {
        processed: processedCount,
        skipped: skippedCount,
        total_queried: unassignedOrdersSnapshot.size,
      });

      // Log warning if we hit the batch limit
      if (unassignedOrdersSnapshot.size === BATCH_LIMIT) {
        console.warn(`[NotifyUnassignedOrders] WARNING: Hit batch limit of ${BATCH_LIMIT}. More unassigned orders may exist. Will process in next run.`);
      }

      // Log analytics event
      console.log('[Analytics] unassigned_orders_notification_batch', {
        processed_count: processedCount,
        total_unassigned: unassignedOrdersSnapshot.size,
      });

      return { processed: processedCount, total: unassignedOrdersSnapshot.size };

    } catch (error) {
      console.error('[NotifyUnassignedOrders] Error processing unassigned orders:', error);

      // Re-throw to mark function as failed in Cloud Functions console
      throw new functions.https.HttpsError(
        'internal',
        'Failed to process unassigned orders',
        error
      );
    }
  });