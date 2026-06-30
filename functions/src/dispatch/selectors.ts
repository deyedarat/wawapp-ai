/**
 * WawApp Dispatch Engine — Driver Selection Logic
 *
 * Optimized driver eligibility checks with Firestore batching.
 *
 * @author WawApp Development Team
 * @version 2.0.0
 */

import * as admin from 'firebase-admin';
import { EligibleDriver } from './types';

const db = admin.firestore();

const MIN_DRIVER_ACCURACY_METERS = 800;
// RELAXED: Location freshness disabled for early-stage (few drivers)
// Re-enable when driver count > 10
// const LOCATION_FRESHNESS_MINUTES = 30;

const PRIORITY_BOOST_TTL_MS = 120_000; // 120 seconds

// ============================================================================
// HAVERSINE DISTANCE
// ============================================================================

/**
 * Calculate distance between two coordinates (Haversine formula)
 */
function calculateDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371; // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) *
    Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// ============================================================================
// DRIVER SELECTION (Optimized for Firestore)
// ============================================================================

/**
 * Find eligible drivers for an order
 *
 * Optimization strategy:
 * - Single query for all driver locations (no pagination)
 * - Local distance filtering (no Firestore reads)
 * - Batch fetch driver profiles (one RPC for all)
 * - Parallel active-order checks (all concurrent)
 * - Sort by distance and return top N
 *
 * @param pickupLat Pickup latitude
 * @param pickupLng Pickup longitude
 * @param maxDistance Maximum distance in km
 * @param maxDrivers Maximum number of drivers to return
 * @returns Sorted array of eligible drivers (closest first)
 */
export async function findEligibleDrivers(
  pickupLat: number,
  pickupLng: number,
  maxDistance: number,
  maxDrivers: number
): Promise<EligibleDriver[]> {
  try {
    // Step 1: Get all driver locations (freshness filter disabled for early-stage)
    const locationsSnapshot = await db
      .collection('driver_locations')
      .get();

    if (locationsSnapshot.empty) {
      console.log('[DriverSelector] No recent driver locations found');
      return [];
    }

    console.log('[DriverSelector] Found recent locations', {
      count: locationsSnapshot.size,
      pickup: { lat: pickupLat, lng: pickupLng },
      max_distance: maxDistance,
    });

    // Step 2: Filter by distance locally (no Firestore reads)
    const nearbyDriverIds: { driverId: string; distance: number }[] = [];

    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const driverId = locationDoc.id;

      // Support both field formats
      const driverLat = locationData.latitude || locationData.lat;
      const driverLng = locationData.longitude || locationData.lng;

      // Skip if location incomplete or inaccurate
      if (
        !driverLat ||
        !driverLng ||
        (locationData.accuracy && locationData.accuracy > MIN_DRIVER_ACCURACY_METERS)
      ) {
        continue;
      }

      const distance = calculateDistance(pickupLat, pickupLng, driverLat, driverLng);

      if (distance <= maxDistance) {
        nearbyDriverIds.push({ driverId, distance });
      }
    }

    if (nearbyDriverIds.length === 0) {
      console.log('[DriverSelector] No drivers within radius', { max_distance: maxDistance });
      return [];
    }

    console.log('[DriverSelector] Drivers within radius', {
      count: nearbyDriverIds.length,
      max_distance: maxDistance,
    });

    // Step 3: Batch-fetch driver profiles (one RPC for all)
    const driverRefs = nearbyDriverIds.map(({ driverId }) =>
      db.collection('drivers').doc(driverId)
    );

    const driverDocs = await db.getAll(...driverRefs);

    // Step 4: Filter by online/verified/complete profiles locally
    const candidateDrivers: Array<{
      driverId: string;
      distance: number;
      driverData: FirebaseFirestore.DocumentData;
    }> = [];

    for (let i = 0; i < driverDocs.length; i++) {
      const driverDoc = driverDocs[i];
      const { driverId, distance } = nearbyDriverIds[i];

      if (!driverDoc.exists) continue;

      const driverData = driverDoc.data()!;

      // Check verified AND online status
      if (driverData.isVerified !== true) {
        continue;
      }

      // Skip offline drivers — they should NOT receive notifications
      if (driverData.isOnline !== true) {
        continue;
      }

      // Check profile completeness
      const { name, vehicleType, vehiclePlate, city, fcmToken } = driverData;

      if (!name || !vehicleType || !vehiclePlate || !city || !fcmToken) {
        console.log('[DriverSelector] Skipping driver with incomplete profile', {
          driver_id: driverId,
          missing: [
            ...(!name ? ['name'] : []),
            ...(!vehicleType ? ['vehicleType'] : []),
            ...(!vehiclePlate ? ['vehiclePlate'] : []),
            ...(!city ? ['city'] : []),
            ...(!fcmToken ? ['fcmToken'] : []),
          ],
        });
        continue;
      }

      candidateDrivers.push({ driverId, distance, driverData });
    }

    if (candidateDrivers.length === 0) {
      console.log('[DriverSelector] No candidates passed profile checks');
      return [];
    }

    console.log('[DriverSelector] Candidates passed profile checks', {
      count: candidateDrivers.length,
    });

    // Step 5: Check for active orders and active offers (parallel)
    const eligibilityChecks = await Promise.all(
      candidateDrivers.map(async ({ driverId, distance, driverData }) => {
        // Check driver dispatch state
        const stateDoc = await db.collection('driver_dispatch_state').doc(driverId).get();

        if (stateDoc.exists) {
          const state = stateDoc.data();

          // Skip if driver has active order
          if (state?.activeOrderId) {
            console.log('[DriverSelector] Skipping driver with active order', {
              driver_id: driverId,
              active_order: state.activeOrderId,
            });
            return null;
          }

          // Skip if driver is busy
          if (state?.status === 'busy') {
            return null;
          }

          // Skip if driver has unexpired offer
          if (state?.activeOfferId) {
            const now = admin.firestore.Timestamp.now();
            const offerDoc = await db.collection('dispatch_offers').doc(state.activeOfferId).get();

            if (offerDoc.exists) {
              const offerData = offerDoc.data();
              if (offerData?.expiresAt && offerData.expiresAt.toMillis() > now.toMillis()) {
                console.log('[DriverSelector] Skipping driver with active offer', {
                  driver_id: driverId,
                  active_offer: state.activeOfferId,
                });
                return null;
              }
            }
          }
        }

        // Final check: active orders in orders collection (fallback)
        const [activeByDriverId, activeByAssignedId] = await Promise.all([
          db
            .collection('orders')
            .where('driverId', '==', driverId)
            .where('status', 'in', ['accepted', 'onRoute'])
            .limit(1)
            .get(),
          db
            .collection('orders')
            .where('assignedDriverId', '==', driverId)
            .where('status', 'in', ['accepted', 'onRoute'])
            .limit(1)
            .get(),
        ]);

        if (!activeByDriverId.empty || !activeByAssignedId.empty) {
          console.log('[DriverSelector] Skipping driver with active order (fallback check)', {
            driver_id: driverId,
          });
          return null;
        }

        // ✅ Driver is eligible
        return {
          driverId,
          distance,
          fcmToken: driverData.fcmToken as string,
          isOnline: true,
          isVerified: true,
          city: driverData.city as string,
          vehicleType: driverData.vehicleType as string,
        } as EligibleDriver;
      })
    );

    // Step 6: Filter nulls, sort by boost + distance, and limit
    const eligibleDrivers = eligibilityChecks.filter(
      (d): d is EligibleDriver => d !== null
    );

    // Build boost lookup from already-fetched driver profiles (no extra reads).
    // driverDocs were batch-fetched in Step 3 and indexed by nearbyDriverIds.
    const boostMap = new Map<string, boolean>();
    const now = admin.firestore.Timestamp.now();
    for (let i = 0; i < driverDocs.length; i++) {
      const doc = driverDocs[i];
      if (!doc.exists) continue;
      const data = doc.data()!;
      if (
        data.priorityBoost === true &&
        data.priorityBoostAt &&
        typeof data.priorityBoostAt.toMillis === 'function' &&
        (now.toMillis() - data.priorityBoostAt.toMillis()) < PRIORITY_BOOST_TTL_MS
      ) {
        boostMap.set(nearbyDriverIds[i].driverId, true);
      }
    }

    // Sort: boosted drivers first, then by distance ascending (stable).
    eligibleDrivers.sort((a, b) => {
      const aBoost = boostMap.has(a.driverId) ? 0 : 1;
      const bBoost = boostMap.has(b.driverId) ? 0 : 1;
      if (aBoost !== bBoost) return aBoost - bBoost;
      return a.distance - b.distance;
    });

    if (boostMap.size > 0) {
      console.log('[DriverSelector] Priority boost applied', {
        boosted_drivers: Array.from(boostMap.keys()),
      });
    }

    const selectedDrivers = eligibleDrivers.slice(0, maxDrivers);

    console.log('[DriverSelector] Final selection', {
      eligible_count: eligibleDrivers.length,
      selected_count: selectedDrivers.length,
      max_drivers: maxDrivers,
      closest_distance: selectedDrivers[0]?.distance.toFixed(2) || 'N/A',
    });

    return selectedDrivers;
  } catch (error: any) {
    console.error('[DriverSelector] Error finding eligible drivers', {
      error: error.message,
      pickup: { lat: pickupLat, lng: pickupLng },
    });
    return [];
  }
}
