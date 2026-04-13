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

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { writeAdminNotification } from './helpers/adminNotifications';

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
  isOnline: boolean;
}

/**
 * Find eligible drivers near pickup location
 */
async function findEligibleDrivers(
  pickupLat: number,
  pickupLng: number
): Promise<EligibleDriver[]> {
  try {
    // Step 1 — Get all recent driver locations (single read)
    const locationsSnapshot = await admin
      .firestore()
      .collection('driver_locations')
      .where('updatedAt', '>', new Date(Date.now() - 15 * 60 * 1000))
      .get();

    if (locationsSnapshot.empty) {
      console.log('[NotifyNewOrder] No recent driver locations found');
      return [];
    }

    // Step 2 — Filter by distance locally (no Firestore reads)
    const nearbyDriverIds: string[] = [];
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const driverLat = locationData.latitude || locationData.lat;
      const driverLng = locationData.longitude || locationData.lng;

      if (
        !driverLat ||
        !driverLng ||
        (locationData.accuracy && locationData.accuracy > MIN_DRIVER_ACCURACY_METERS)
      ) {
        continue;
      }

      const distance = calculateDistance(pickupLat, pickupLng, driverLat, driverLng);
      if (distance <= MAX_NOTIFICATION_RADIUS_KM) {
        nearbyDriverIds.push(locationDoc.id);
      }
    }

    if (nearbyDriverIds.length === 0) return [];

    // Step 3 — Batch-fetch all driver profiles in one RPC
    const driverRefs = nearbyDriverIds.map((id) =>
      admin.firestore().collection('drivers').doc(id)
    );
    const driverDocs = await admin.firestore().getAll(...driverRefs);

    // Step 4 — Filter offline / unverified / incomplete profiles locally
    const candidateDrivers: Array<{ driverId: string; distance: number; driverData: FirebaseFirestore.DocumentData }> = [];
    for (const driverDoc of driverDocs) {
      if (!driverDoc.exists) continue;
      const driverData = driverDoc.data()!;
      if (driverData.isOnline !== true || driverData.isVerified !== true) continue;
      const { name, vehicleType, vehiclePlate, city } = driverData;
      if (!name || !vehicleType || !vehiclePlate || !city) {
        console.log('[NotifyNewOrder] Skipping driver with incomplete profile', {
          driver_id: driverDoc.id,
          missing: [
            ...(!name ? ['name'] : []),
            ...(!vehicleType ? ['vehicleType'] : []),
            ...(!vehiclePlate ? ['vehiclePlate'] : []),
            ...(!city ? ['city'] : []),
          ],
        });
        continue;
      }

      // Recalculate distance (already filtered above, but needed for sorting)
      const locationDoc = locationsSnapshot.docs.find((d) => d.id === driverDoc.id);
      if (!locationDoc) continue;
      const locationData = locationDoc.data();
      const driverLat = locationData.latitude || locationData.lat;
      const driverLng = locationData.longitude || locationData.lng;
      const distance = calculateDistance(pickupLat, pickupLng, driverLat, driverLng);

      candidateDrivers.push({ driverId: driverDoc.id, distance, driverData });
    }

    if (candidateDrivers.length === 0) return [];

    // Step 5 — Check active orders in parallel (2 queries per candidate, all concurrent)
    const activeOrderChecks = await Promise.all(
      candidateDrivers.map(async ({ driverId, distance, driverData }) => {
        const [activeByDriverId, activeByAssignedId] = await Promise.all([
          admin.firestore()
            .collection('orders')
            .where('driverId', '==', driverId)
            .where('status', 'in', ['accepted', 'onRoute'])
            .limit(1)
            .get(),
          admin.firestore()
            .collection('orders')
            .where('assignedDriverId', '==', driverId)
            .where('status', 'in', ['accepted', 'onRoute'])
            .limit(1)
            .get(),
        ]);

        if (!activeByDriverId.empty || !activeByAssignedId.empty) {
          console.log('[NotifyNewOrder] Skipping driver with active order', { driver_id: driverId });
          return null;
        }

        return {
          driverId,
          distance,
          fcmToken: driverData.fcmToken as string | undefined,
          isOnline: true,
        } as EligibleDriver;
      })
    );

    // Step 6 — Sort by distance and return top N
    const eligibleDrivers = activeOrderChecks.filter((d): d is EligibleDriver => d !== null);
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
    // Resolve pickup/dropoff fields — support both formats:
    // New: pickup.label, pickup.lat | Legacy: pickupAddress.label, pickupAddress.latitude
    const pickupLabel = orderData.pickup?.label || (typeof orderData.pickupAddress === 'string' ? orderData.pickupAddress : orderData.pickupAddress?.label) || 'موقع الانطلاق';
    const dropoffLabel = orderData.dropoff?.label || (typeof orderData.dropoffAddress === 'string' ? orderData.dropoffAddress : orderData.dropoffAddress?.label) || 'الوجهة';
    const pLat = orderData.pickup?.lat || orderData.pickupAddress?.latitude || 0;
    const pLng = orderData.pickup?.lng || orderData.pickupAddress?.longitude || 0;
    const dLat = orderData.dropoff?.lat || orderData.dropoffAddress?.latitude || 0;
    const dLng = orderData.dropoff?.lng || orderData.dropoffAddress?.longitude || 0;

    const message: admin.messaging.Message = {
      token: driver.fcmToken,
      data: {
        notificationType: 'new_order',
        type: 'new_order',
        title: 'طلب جديد قريب منك',
        body: `${pickupLabel} → ${dropoffLabel}`,
        orderId: orderId,
        pickupLat: String(pLat),
        pickupLng: String(pLng),
        dropoffLat: String(dLat),
        dropoffLng: String(dLng),
        pickupLabel: pickupLabel,
        dropoffLabel: dropoffLabel,
        price: String(orderData.price || 0),
        clientName: orderData.clientName || 'عميل',
        createdAt: String(orderData.createdAt?.toMillis() || Date.now()),
        distance: String(driver.distance.toFixed(2)),
      },
      android: {
        priority: 'high',
        ttl: 60000, // 60s — stale notifications are useless and bypass busy-check
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

    // Validate pickup location - support both formats
    const pickupLat = orderData.pickup?.lat;
    const pickupLng = orderData.pickup?.lng;
    
    if (!pickupLat || !pickupLng) {
      console.warn('[NotifyNewOrder] Order missing pickup coordinates', {
        order_id: orderId,
        pickup_address: orderData.pickupAddress,
        pickup: orderData.pickup,
      });
      return null;
    }

    // Find eligible drivers near pickup location
    const eligibleDrivers = await findEligibleDrivers(pickupLat, pickupLng);

    if (eligibleDrivers.length === 0) {
      console.log('[NotifyNewOrder] No eligible drivers found', {
        order_id: orderId,
        pickup_lat: pickupLat,
        pickup_lng: pickupLng,
      });
      // Still write admin notification even when no drivers found
      await writeAdminNotification({
        type: 'new_order',
        title: 'طلب جديد',
        body: `طلب جديد #${orderId.substring(0, 6)} — ${orderData.pickup?.label || orderData.pickupAddress || 'موقع الانطلاق'} → ${orderData.dropoff?.label || orderData.dropoffAddress || 'الوجهة'}`,
        data: {
          orderId,
          clientName: orderData.clientName || '',
        },
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

    // Write admin notification
    await writeAdminNotification({
      type: 'new_order',
      title: 'طلب جديد',
      body: `طلب جديد #${orderId.substring(0, 6)} — ${orderData.pickup?.label || orderData.pickupAddress || 'موقع الانطلاق'} → ${orderData.dropoff?.label || orderData.dropoffAddress || 'الوجهة'}`,
      data: {
        orderId,
        clientName: orderData.clientName || '',
      },
    });

    return null;
  });
