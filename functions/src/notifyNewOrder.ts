/**
 * Cloud Function: Notify Drivers of New Orders
 * 
 * CRITICAL FIX: Sends FCM push notifications to eligible nearby drivers
 * when a client creates a new order.
 * 
 * Triggers on: orders/{orderId} onCreate
 * 
 * Author: WawApp Development Team (Critical Fix)
 * Last Updated: 2025-12-28
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Configuration constants
 */
const MAX_NOTIFICATION_RADIUS_KM = 10; // Maximum radius to search for drivers
const MAX_DRIVERS_TO_NOTIFY = 20; // Limit concurrent notifications
const MIN_DRIVER_ACCURACY_METERS = 100; // Filter out inaccurate location data

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
  online: boolean;
  available: boolean;
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
      console.log('[NotifyNewOrder] No recent driver locations found');
      return [];
    }

    // Process each driver location
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const driverId = locationDoc.id;

      // Skip if location data is incomplete or inaccurate
      if (
        !locationData.latitude ||
        !locationData.longitude ||
        (locationData.accuracy && locationData.accuracy > MIN_DRIVER_ACCURACY_METERS)
      ) {
        continue;
      }

      // Calculate distance from pickup location
      const distance = calculateDistance(
        pickupLat,
        pickupLng,
        locationData.latitude,
        locationData.longitude
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

      // Check if driver is online and available
      const online = driverData?.online === true;
      const available = driverData?.available === true;

      // Only notify online AND available drivers
      if (!online || !available) {
        continue;
      }

      eligibleDrivers.push({
        driverId,
        distance,
        fcmToken: driverData?.fcmToken as string | undefined,
        online,
        available,
      });
    }

    // Sort by distance (closest first) and limit
    eligibleDrivers.sort((a, b) => a.distance - b.distance);
    return eligibleDrivers.slice(0, MAX_DRIVERS_TO_NOTIFY);
  } catch (error: any) {
    console.error('[NotifyNewOrder] Error finding eligible drivers:', {
      error: error.message,
      pickup_lat: pickupLat,
      pickup_lng: pickupLng,
    });
    return [];
  }
}

/**
 * Send FCM notification to driver with retry logic
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

  try {
    // Prepare notification data payload (for deep-link reliability)
    const message: admin.messaging.Message = {
      token: driver.fcmToken,
      notification: {
        title: 'طلب جديد قريب منك',
        body: `${orderData.pickupAddress?.label || 'موقع الانطلاق'} → ${
          orderData.dropoffAddress?.label || 'الوجهة'
        }`,
      },
      data: {
        notificationType: 'new_order',
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
          channelId: 'new_orders', // Must match Android channel in driver app
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

    console.log('[NotifyNewOrder] Notification sent to driver', {
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
      console.warn('[NotifyNewOrder] Invalid FCM token, removing from driver', {
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
          console.error('[NotifyNewOrder] Failed to remove invalid token:', err)
        );

      return {
        success: false,
        error: 'invalid_token',
      };
    }

    // Log other errors but don't fail
    console.error('[NotifyNewOrder] Failed to send notification to driver', {
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
 * Cloud Function: Trigger on order creation
 */
export const notifyNewOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snapshot, context) => {
    const orderId = context.params.orderId;
    const orderData = snapshot.data();

    console.log('[NotifyNewOrder] New order created', {
      order_id: orderId,
      status: orderData.status,
      created_at: orderData.createdAt,
    });

    // Only process orders in 'matching' status (new orders looking for drivers)
    if (orderData.status !== 'matching') {
      console.log('[NotifyNewOrder] Order not in matching status, skipping', {
        order_id: orderId,
        status: orderData.status,
      });
      return null;
    }

    // Validate pickup location
    if (
      !orderData.pickupAddress?.latitude ||
      !orderData.pickupAddress?.longitude
    ) {
      console.warn('[NotifyNewOrder] Order missing pickup coordinates', {
        order_id: orderId,
      });
      return null;
    }

    const pickupLat = orderData.pickupAddress.latitude;
    const pickupLng = orderData.pickupAddress.longitude;

    // Find eligible drivers near pickup location
    const eligibleDrivers = await findEligibleDrivers(pickupLat, pickupLng);

    if (eligibleDrivers.length === 0) {
      console.log('[NotifyNewOrder] No eligible drivers found', {
        order_id: orderId,
        pickup_lat: pickupLat,
        pickup_lng: pickupLng,
      });
      return null;
    }

    console.log('[NotifyNewOrder] Found eligible drivers', {
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
    console.log('[NotifyNewOrder] Notification summary', {
      order_id: orderId,
      candidate_drivers: eligibleDrivers.length,
      sent_count: sentCount,
      failed_count: failedCount,
      failure_reasons: JSON.stringify(failureReasons),
    });

    // Log analytics event
    console.log('[Analytics] new_order_notifications_sent', {
      order_id: orderId,
      drivers_notified: sentCount,
      drivers_failed: failedCount,
      pickup_lat: pickupLat,
      pickup_lng: pickupLng,
    });

    return null;
  });
