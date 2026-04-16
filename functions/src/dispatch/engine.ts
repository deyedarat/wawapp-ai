/**
 * WawApp Dispatch Engine — Core Logic
 *
 * Production-grade hybrid sequential-wave dispatch system.
 *
 * Architecture:
 * - Wave 1: Closest driver (15s timeout)
 * - Wave 2: 3 nearby drivers (30s timeout)
 * - Wave 3: 5 farther drivers (45s timeout)
 *
 * Features:
 * - Single source of truth (dispatch_queue + driver_dispatch_state)
 * - Atomic offer creation (prevents race conditions)
 * - Real-time state management
 * - Zero duplicates
 * - Firestore-optimized (batch reads, parallel queries)
 *
 * @author WawApp Development Team
 * @version 2.0.0
 */

import * as admin from 'firebase-admin';
import {
  DriverDispatchState,
  DispatchOffer,
  DispatchQueueEntry,
  EligibleDriver,
  DEFAULT_WAVES,
  DispatchMetrics,
} from './types';
import { findEligibleDrivers } from './selectors';
import { sendOfferNotification } from './notifications';

const db = admin.firestore();

// ============================================================================
// CONSTANTS
// ============================================================================

const LOCK_TTL_SECONDS = 30;

// ============================================================================
// DISPATCH QUEUE MANAGEMENT
// ============================================================================

/**
 * Add order to dispatch queue
 *
 * Called when a new order enters 'matching' status.
 */
export async function enqueueOrder(
  orderId: string,
  pickupLat: number,
  pickupLng: number,
  price: number,
  clientName?: string
): Promise<void> {
  const now = admin.firestore.Timestamp.now();

  const queueEntry: DispatchQueueEntry = {
    orderId,
    currentWave: 0,               // Start before wave 1
    totalOffersSent: 0,

    waveStartedAt: null,
    waveExpiresAt: null,

    pickupLat,
    pickupLng,
    price,
    clientName,

    createdAt: now,
    updatedAt: now,
  };

  await db.collection('dispatch_queue').doc(orderId).set(queueEntry);

  console.log('[DispatchEngine] Order enqueued', {
    order_id: orderId,
    pickup: { lat: pickupLat, lng: pickupLng },
  });

  // Initialize dispatch metrics
  const metrics: DispatchMetrics = {
    orderId,
    waveMetrics: [],
    acceptedByDriverId: null,
    acceptedAtWave: null,
    totalDriversNotified: 0,
    firstOfferAt: now,
    acceptedAt: null,
    timeToAcceptSeconds: null,
    createdAt: now,
  };

  await db.collection('dispatch_metrics').doc(orderId).set(metrics);

  // Immediately trigger wave 1
  await processNextWave(orderId);
}

/**
 * Remove order from dispatch queue
 *
 * Called when order is accepted, cancelled, or expired.
 */
export async function dequeueOrder(orderId: string): Promise<void> {
  await db.collection('dispatch_queue').doc(orderId).delete();

  console.log('[DispatchEngine] Order dequeued', { order_id: orderId });
}

// ============================================================================
// WAVE PROCESSING (Hybrid Sequential Model)
// ============================================================================

/**
 * Process next wave for an order
 *
 * Core dispatch logic. Called:
 * - Initially when order is created
 * - When previous wave expires without acceptance
 * - By scheduled function (processExpiredWaves)
 */
export async function processNextWave(orderId: string): Promise<void> {
  const queueRef = db.collection('dispatch_queue').doc(orderId);

  try {
    await db.runTransaction(async (transaction) => {
      const queueDoc = await transaction.get(queueRef);

      if (!queueDoc.exists) {
        console.log('[DispatchEngine] Order no longer in queue', { order_id: orderId });
        return;
      }

      const queueData = queueDoc.data() as DispatchQueueEntry;
      const nextWaveNum = queueData.currentWave + 1;

      // Check if we have more waves available
      if (nextWaveNum > DEFAULT_WAVES.length) {
        console.warn('[DispatchEngine] All waves exhausted, no driver found', {
          order_id: orderId,
          total_waves: DEFAULT_WAVES.length,
        });
        // Don't dequeue yet — admin should handle manually
        return;
      }

      const wave = DEFAULT_WAVES[nextWaveNum - 1];
      const now = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromMillis(
        now.toMillis() + wave.ttl * 1000
      );

      // Update queue entry
      transaction.update(queueRef, {
        currentWave: nextWaveNum,
        waveStartedAt: now,
        waveExpiresAt: expiresAt,
        updatedAt: now,
      });

      console.log('[DispatchEngine] Starting wave', {
        order_id: orderId,
        wave: nextWaveNum,
        max_drivers: wave.maxDrivers,
        ttl_seconds: wave.ttl,
      });
    });

    // After transaction: send offers (non-blocking for transaction)
    await sendWaveOffers(orderId);

  } catch (error: any) {
    console.error('[DispatchEngine] Error processing wave', {
      order_id: orderId,
      error: error.message,
    });
  }
}

/**
 * Send offers for current wave
 *
 * Selects eligible drivers and creates offer documents atomically.
 */
async function sendWaveOffers(orderId: string): Promise<void> {
  const queueDoc = await db.collection('dispatch_queue').doc(orderId).get();

  if (!queueDoc.exists) return;

  const queueData = queueDoc.data() as DispatchQueueEntry;
  const wave = DEFAULT_WAVES[queueData.currentWave - 1];

  // Find eligible drivers
  const eligibleDrivers = await findEligibleDrivers(
    queueData.pickupLat,
    queueData.pickupLng,
    wave.maxDistance,
    wave.maxDrivers
  );

  if (eligibleDrivers.length === 0) {
    console.warn('[DispatchEngine] No eligible drivers for wave', {
      order_id: orderId,
      wave: queueData.currentWave,
    });
    // Wait for wave expiration, then try next wave
    return;
  }

  console.log('[DispatchEngine] Found eligible drivers', {
    order_id: orderId,
    wave: queueData.currentWave,
    driver_count: eligibleDrivers.length,
    closest_distance: eligibleDrivers[0].distance.toFixed(2),
  });

  // Create offers atomically (batch write)
  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + wave.ttl * 1000
  );

  const offers: DispatchOffer[] = [];

  for (let i = 0; i < eligibleDrivers.length; i++) {
    const driver = eligibleDrivers[i];
    const offerId = `${orderId}_${driver.driverId}`;

    const offer: DispatchOffer = {
      offerId,
      orderId,
      driverId: driver.driverId,
      status: 'sent',
      round: queueData.currentWave,
      priority: i + 1,              // 1 = closest
      sentAt: now,
      expiresAt,
      respondedAt: null,
      distance: driver.distance,
      createdAt: now,
    };

    offers.push(offer);
    batch.set(db.collection('dispatch_offers').doc(offerId), offer);

    // Update driver state (mark as having active offer)
    batch.set(db.collection('driver_dispatch_state').doc(driver.driverId), {
      driverId: driver.driverId,
      activeOfferId: offerId,
      lastOfferAt: now,
      updatedAt: now,
    }, { merge: true });
  }

  // Update metrics
  batch.update(db.collection('dispatch_metrics').doc(orderId), {
    [`waveMetrics`]: admin.firestore.FieldValue.arrayUnion({
      round: queueData.currentWave,
      driversSent: eligibleDrivers.length,
      rejections: 0,
      expirations: 0,
      startedAt: now,
      completedAt: null,
    }),
    totalDriversNotified: admin.firestore.FieldValue.increment(eligibleDrivers.length),
  });

  // Update queue total offers sent
  batch.update(db.collection('dispatch_queue').doc(orderId), {
    totalOffersSent: admin.firestore.FieldValue.increment(eligibleDrivers.length),
  });

  await batch.commit();

  console.log('[DispatchEngine] Offers created', {
    order_id: orderId,
    wave: queueData.currentWave,
    offers_sent: offers.length,
  });

  // Send FCM notifications (non-blocking, fire-and-forget)
  sendWaveNotifications(orderId, offers, eligibleDrivers);
}

/**
 * Send FCM notifications for wave offers
 *
 * Runs asynchronously after offer documents are created.
 */
async function sendWaveNotifications(
  orderId: string,
  offers: DispatchOffer[],
  drivers: EligibleDriver[]
): Promise<void> {
  // Fetch full order data for notification payload
  const orderDoc = await db.collection('orders').doc(orderId).get();

  if (!orderDoc.exists) {
    console.error('[DispatchEngine] Order not found for notifications', { order_id: orderId });
    return;
  }

  const orderData = orderDoc.data()!;

  const notificationPromises = offers.map(async (offer, index) => {
    const driver = drivers[index];

    try {
      const result = await sendOfferNotification(offer, orderData, driver.fcmToken);

      if (result.success) {
        // Update offer with FCM message ID
        await db.collection('dispatch_offers').doc(offer.offerId).update({
          fcmMessageId: result.messageId,
        });
      } else {
        console.warn('[DispatchEngine] Failed to send notification', {
          offer_id: offer.offerId,
          error: result.error,
        });
      }
    } catch (error: any) {
      console.error('[DispatchEngine] Notification error', {
        offer_id: offer.offerId,
        error: error.message,
      });
    }
  });

  await Promise.allSettled(notificationPromises);
}

// ============================================================================
// WAVE EXPIRATION HANDLER
// ============================================================================

/**
 * Process expired waves (called by scheduled function)
 *
 * Finds all dispatch queue entries where waveExpiresAt < now
 * and triggers next wave.
 */
export async function processExpiredWaves(): Promise<void> {
  const now = admin.firestore.Timestamp.now();

  const expiredSnapshot = await db
    .collection('dispatch_queue')
    .where('waveExpiresAt', '<=', now)
    .limit(50)
    .get();

  if (expiredSnapshot.empty) {
    console.log('[DispatchEngine] No expired waves to process');
    return;
  }

  console.log('[DispatchEngine] Processing expired waves', { count: expiredSnapshot.size });

  const promises = expiredSnapshot.docs.map(async (doc) => {
    const orderId = doc.id;
    const queueData = doc.data() as DispatchQueueEntry;

    console.log('[DispatchEngine] Wave expired, moving to next', {
      order_id: orderId,
      expired_wave: queueData.currentWave,
    });

    // Mark current wave as completed in metrics
    await db.collection('dispatch_metrics').doc(orderId).update({
      [`waveMetrics.${queueData.currentWave - 1}.completedAt`]: now,
    });

    // Expire all sent offers from this wave
    const sentOffers = await db
      .collection('dispatch_offers')
      .where('orderId', '==', orderId)
      .where('round', '==', queueData.currentWave)
      .where('status', '==', 'sent')
      .get();

    if (!sentOffers.empty) {
      const batch = db.batch();
      sentOffers.docs.forEach((offerDoc) => {
        batch.update(offerDoc.ref, { status: 'expired', respondedAt: now });
      });
      await batch.commit();

      console.log('[DispatchEngine] Expired sent offers', {
        order_id: orderId,
        count: sentOffers.size,
      });
    }

    // Trigger next wave
    await processNextWave(orderId);
  });

  await Promise.allSettled(promises);
}

// ============================================================================
// ACCEPTANCE HANDLER
// ============================================================================

/**
 * Handle offer acceptance
 *
 * Called when driver accepts an offer.
 * Atomically updates order status and expires all other offers.
 */
export async function handleOfferAcceptance(
  offerId: string,
  driverId: string
): Promise<{ success: boolean; error?: string }> {
  const offerRef = db.collection('dispatch_offers').doc(offerId);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const offerDoc = await transaction.get(offerRef);

      if (!offerDoc.exists) {
        return { success: false, error: 'offer_not_found' };
      }

      const offer = offerDoc.data() as DispatchOffer;

      // Validate offer is for this driver
      if (offer.driverId !== driverId) {
        return { success: false, error: 'driver_mismatch' };
      }

      // Validate offer status
      if (offer.status !== 'sent') {
        return { success: false, error: `offer_${offer.status}` };
      }

      // Check expiration
      const now = admin.firestore.Timestamp.now();
      if (offer.expiresAt.toMillis() < now.toMillis()) {
        transaction.update(offerRef, { status: 'expired', respondedAt: now });
        return { success: false, error: 'offer_expired' };
      }

      // Check driver state (prevent double-acceptance)
      const driverStateRef = db.collection('driver_dispatch_state').doc(driverId);
      const driverStateDoc = await transaction.get(driverStateRef);

      if (driverStateDoc.exists) {
        const state = driverStateDoc.data() as DriverDispatchState;
        if (state.acceptanceLock && state.lockExpiresAt && state.lockExpiresAt.toMillis() > now.toMillis()) {
          return { success: false, error: 'driver_locked' };
        }
      }

      // Check order status
      const orderRef = db.collection('orders').doc(offer.orderId);
      const orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        return { success: false, error: 'order_not_found' };
      }

      const orderData = orderDoc.data()!;

      if (orderData.status !== 'matching') {
        return { success: false, error: 'order_already_assigned' };
      }

      if (orderData.assignedDriverId) {
        return { success: false, error: 'order_already_assigned' };
      }

      // ✅ ALL CHECKS PASSED — ACCEPT OFFER

      // 1. Update order
      transaction.update(orderRef, {
        status: 'accepted',
        assignedDriverId: driverId,
        driverId: driverId,
        acceptedAt: now,
        updatedAt: now,
      });

      // 2. Update offer
      transaction.update(offerRef, {
        status: 'accepted',
        respondedAt: now,
      });

      // 3. Lock driver state
      const lockExpiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + LOCK_TTL_SECONDS * 1000);

      transaction.set(driverStateRef, {
        driverId,
        status: 'busy',
        activeOfferId: offerId,
        activeOrderId: offer.orderId,
        acceptanceLock: true,
        lockExpiresAt,
        updatedAt: now,
      }, { merge: true });

      // 4. Update metrics
      const metricsRef = db.collection('dispatch_metrics').doc(offer.orderId);
      transaction.update(metricsRef, {
        acceptedByDriverId: driverId,
        acceptedAtWave: offer.round,
        acceptedAt: now,
        timeToAcceptSeconds: Math.floor((now.toMillis() - orderData.createdAt.toMillis()) / 1000),
      });

      return { success: true };
    });

    if (!result.success) {
      return result;
    }

    // After transaction: expire other offers and remove from queue
    const offerDoc = await offerRef.get();
    const offer = offerDoc.data() as DispatchOffer;

    // Expire all other offers for this order
    const otherOffers = await db
      .collection('dispatch_offers')
      .where('orderId', '==', offer.orderId)
      .where('status', '==', 'sent')
      .get();

    if (!otherOffers.empty) {
      const batch = db.batch();
      otherOffers.docs.forEach((doc) => {
        if (doc.id !== offerId) {
          batch.update(doc.ref, { status: 'cancelled', respondedAt: admin.firestore.Timestamp.now() });
        }
      });
      await batch.commit();
    }

    // Remove from dispatch queue
    await dequeueOrder(offer.orderId);

    console.log('[DispatchEngine] Offer accepted', {
      offer_id: offerId,
      order_id: offer.orderId,
      driver_id: driverId,
      wave: offer.round,
    });

    return { success: true };

  } catch (error: any) {
    console.error('[DispatchEngine] Error handling acceptance', {
      offer_id: offerId,
      driver_id: driverId,
      error: error.message,
    });
    return { success: false, error: 'internal_error' };
  }
}

// ============================================================================
// REJECTION HANDLER
// ============================================================================

/**
 * Handle offer rejection
 *
 * Called when driver explicitly rejects an offer.
 */
export async function handleOfferRejection(
  offerId: string,
  driverId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const now = admin.firestore.Timestamp.now();

    await db.runTransaction(async (transaction) => {
      const offerRef = db.collection('dispatch_offers').doc(offerId);
      const offerDoc = await transaction.get(offerRef);

      if (!offerDoc.exists) {
        throw new Error('offer_not_found');
      }

      const offer = offerDoc.data() as DispatchOffer;

      if (offer.driverId !== driverId) {
        throw new Error('driver_mismatch');
      }

      if (offer.status !== 'sent') {
        throw new Error(`offer_${offer.status}`);
      }

      // Update offer status
      transaction.update(offerRef, {
        status: 'rejected',
        respondedAt: now,
      });

      // Update driver state (clear active offer)
      transaction.update(db.collection('driver_dispatch_state').doc(driverId), {
        activeOfferId: null,
        updatedAt: now,
      });

      // Update metrics
      const metricsRef = db.collection('dispatch_metrics').doc(offer.orderId);
      transaction.update(metricsRef, {
        [`waveMetrics.${offer.round - 1}.rejections`]: admin.firestore.FieldValue.increment(1),
      });
    });

    console.log('[DispatchEngine] Offer rejected', {
      offer_id: offerId,
      driver_id: driverId,
    });

    return { success: true };

  } catch (error: any) {
    console.error('[DispatchEngine] Error handling rejection', {
      offer_id: offerId,
      driver_id: driverId,
      error: error.message,
    });
    return { success: false, error: error.message };
  }
}
