/**
 * Cloud Function: Get Nearby Orders for Driver
 * 
 * Returns matching orders near the driver's current location.
 * This bypasses Firestore Rules to allow drivers to see available orders
 * without exposing PII.
 * 
 * Author: WawApp Development Team
 * Last Updated: 2026-02-01
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';

/**
 * Configuration constants
 */
const MAX_SEARCH_RADIUS_KM = 50; // Relaxed for early-stage (few drivers). Restore to 8 when driver count > 10
const MAX_ORDERS_TO_RETURN = 20; // Limit results

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
 * Cloud Function: Get nearby orders for authenticated driver
 */
export const getNearbyOrders = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Driver must be authenticated'
    );
  }

  const driverId = context.auth.uid;
  const driverLat = data.lat as number;
  const driverLng = data.lng as number;

  // Validate input
  if (
    typeof driverLat !== 'number' ||
    typeof driverLng !== 'number' ||
    driverLat < -90 ||
    driverLat > 90 ||
    driverLng < -180 ||
    driverLng > 180
  ) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid driver location coordinates'
    );
  }

  console.log('[getNearbyOrders] Request from driver', {
    driver_id: driverId,
    lat: driverLat.toFixed(6),
    lng: driverLng.toFixed(6),
  });

  try {
    // Check if driver is online
    const driverDoc = await admin
      .firestore()
      .collection('drivers')
      .doc(driverId)
      .get();

    if (!driverDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Driver profile not found'
      );
    }

    const driverData = driverDoc.data();

    if (driverData?.isBlocked) {
      console.log('[getNearbyOrders] Driver is blocked', { driver_id: driverId });
      throw new functions.https.HttpsError(
        'permission-denied',
        'Driver account is blocked'
      );
    }

    if (!driverData?.isVerified) {
      console.log('[getNearbyOrders] Driver not verified', { driver_id: driverId });
      throw new functions.https.HttpsError(
        'permission-denied',
        'Driver account is not verified'
      );
    }

    // Online check removed for early-stage: driver sees orders whenever app is open
    // Re-enable when driver count > 10:
    // if (!driverData?.isOnline) {
    //   return { orders: [] };
    // }

    // Skip if driver has an active order (accepted or onRoute)
    const activeOrderSnapshot = await admin
      .firestore()
      .collection('orders')
      .where('driverId', '==', driverId)
      .where('status', 'in', ['accepted', 'onRoute'])
      .limit(1)
      .get();

    if (!activeOrderSnapshot.empty) {
      console.log('[getNearbyOrders] Driver has active order, returning empty', {
        driver_id: driverId,
        active_order_id: activeOrderSnapshot.docs[0].id,
        active_status: activeOrderSnapshot.docs[0].data().status,
      });
      return { orders: [] };
    }

    // Query matching orders
    const ordersSnapshot = await admin
      .firestore()
      .collection('orders')
      .where('status', '==', 'matching')
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    // Get rejected order IDs for this driver
    const rejectedSnapshot = await admin
      .firestore()
      .collection('driver_rejected_orders')
      .where('driverId', '==', driverId)
      .where('expiresAt', '>', admin.firestore.Timestamp.now())
      .get();

    const rejectedOrderIds = new Set(
      rejectedSnapshot.docs.map(doc => doc.data().orderId as string)
    );

    console.log('[getNearbyOrders] Found orders in matching status', {
      count: ordersSnapshot.size,
    });

    const nearbyOrders: any[] = [];

    for (const doc of ordersSnapshot.docs) {
      const orderData = doc.data();

      // Skip if already assigned
      if (orderData.assignedDriverId) {
        continue;
      }

      // Skip if driver rejected this order
      if (rejectedOrderIds.has(doc.id)) {
        continue;
      }

      // Skip if this driver previously cancelled/timed out on this order
      if (orderData.previousDriverId === driverId) {
        continue;
      }

      // Get pickup location
      const pickupLat = orderData.pickup?.lat;
      const pickupLng = orderData.pickup?.lng;

      if (!pickupLat || !pickupLng) {
        continue;
      }

      // Calculate distance
      const distance = calculateDistance(
        driverLat,
        driverLng,
        pickupLat,
        pickupLng
      );

      // Skip if too far
      if (distance > MAX_SEARCH_RADIUS_KM) {
        continue;
      }

      // Add to results (sanitize PII)
      nearbyOrders.push({
        id: doc.id,
        pickup: orderData.pickup,
        dropoff: orderData.dropoff,
        price: orderData.price,
        distanceKm: orderData.distanceKm,
        status: orderData.status,
        createdAt: orderData.createdAt,
        distance: parseFloat(distance.toFixed(2)),
      });
    }

    // Sort by distance and limit
    nearbyOrders.sort((a, b) => a.distance - b.distance);
    const limitedOrders = nearbyOrders.slice(0, MAX_ORDERS_TO_RETURN);

    console.log('[getNearbyOrders] Returning nearby orders', {
      driver_id: driverId,
      total_matching: ordersSnapshot.size,
      nearby_count: limitedOrders.length,
    });

    return { orders: limitedOrders };
  } catch (error: any) {
    console.error('[getNearbyOrders] Error', {
      driver_id: driverId,
      error: error.message,
    });

    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch nearby orders'
    );
  }
});
