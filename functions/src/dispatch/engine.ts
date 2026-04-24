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
import { CloudTasksClient } from '@google-cloud/tasks';
import {
  DriverDispatchState,
  DispatchOffer,
  DispatchQueueEntry,
  EligibleDriver,
  DEFAULT_WAVES,
  REPEAT_WAVE,
  DispatchMetrics,
} from './types';
import { NormalizedDispatchPayload, removeUndefinedDeep } from './intake';
import { findEligibleDrivers } from './selectors';
import { sendOfferNotification } from './notifications';
import { emitMetric, DispatchMetricName } from './counters';

const db = admin.firestore();

// ============================================================================
// CONSTANTS
// ============================================================================

const LOCK_TTL_SECONDS = 30;

// ============================================================================
// CIRCUIT BREAKER STATE (in-memory, per Cloud Function instance)
// ============================================================================

/** Per-order consecutive failure tracker */
const orderFailureCounts = new Map<string, number>();
const ORDER_CIRCUIT_BREAKER_THRESHOLD = 3;

/** Global circuit breaker: sliding window of failures */
let globalFailureWindow: number[] = [];
const GLOBAL_CB_WINDOW_MS = 60_000; // 1 minute
const GLOBAL_CB_THRESHOLD = 10; // 10 failures in 1 minute
let globalCircuitOpen = false;
let globalCircuitOpenUntil = 0;
const GLOBAL_CB_COOLDOWN_MS = 30_000; // pause 30s

function recordOrderFailure(orderId: string): number {
  const count = (orderFailureCounts.get(orderId) || 0) + 1;
  orderFailureCounts.set(orderId, count);
  return count;
}

function clearOrderFailure(orderId: string): void {
  orderFailureCounts.delete(orderId);
}

function recordGlobalFailure(): void {
  const now = Date.now();
  globalFailureWindow.push(now);
  // Prune old entries
  globalFailureWindow = globalFailureWindow.filter((t) => now - t < GLOBAL_CB_WINDOW_MS);
  if (globalFailureWindow.length >= GLOBAL_CB_THRESHOLD) {
    globalCircuitOpen = true;
    globalCircuitOpenUntil = now + GLOBAL_CB_COOLDOWN_MS;
    console.error(JSON.stringify({
      tag: 'CircuitBreaker',
      level: 'CRITICAL',
      result: 'global_circuit_opened',
      failureCount: globalFailureWindow.length,
      cooldownMs: GLOBAL_CB_COOLDOWN_MS,
    }));
  }
}

function isGlobalCircuitOpen(): boolean {
  if (!globalCircuitOpen) return false;
  if (Date.now() > globalCircuitOpenUntil) {
    globalCircuitOpen = false;
    globalFailureWindow = [];
    console.log(JSON.stringify({
      tag: 'CircuitBreaker',
      result: 'global_circuit_closed',
    }));
    return false;
  }
  return true;
}

// ============================================================================
// RETRY HELPER (exponential backoff, idempotent)
// ============================================================================

async function withRetry<T>(
  fn: () => Promise<T>,
  opts: { maxAttempts?: number; label?: string; orderId?: string } = {}
): Promise<T> {
  const maxAttempts = opts.maxAttempts ?? 3;
  let lastError: any;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      lastError = err;
      // Non-retryable errors: don't retry
      if (isNonRetryable(err)) throw err;
      if (attempt < maxAttempts) {
        const delayMs = Math.min(1000 * Math.pow(2, attempt - 1), 8000);
        console.warn(JSON.stringify({
          tag: 'Retry',
          label: opts.label,
          orderId: opts.orderId,
          attempt,
          maxAttempts,
          delayMs,
          error: err.message,
        }));
        await sleep(delayMs);
      }
    }
  }
  throw lastError;
}

function isNonRetryable(err: any): boolean {
  // Validation errors, permission errors, not-found are non-retryable
  const code = err.code || '';
  return (
    code === 'not-found' ||
    code === 'permission-denied' ||
    code === 'invalid-argument' ||
    err.message?.includes('validation_failed')
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ============================================================================
// DISPATCH QUEUE MANAGEMENT
// ============================================================================

/**
 * Add order to dispatch queue
 *
 * Called ONLY via safeEnqueueOrder (intake boundary).
 * Accepts a pre-validated, normalized payload — never raw order data.
 */
export async function enqueueOrder(
  payload: NormalizedDispatchPayload
): Promise<void> {
  const { orderId, pickupLat, pickupLng, price, clientName } = payload;
  const now = admin.firestore.Timestamp.now();

  const queueEntry: DispatchQueueEntry = {
    orderId,
    currentWave: 0,
    totalOffersSent: 0,

    waveStatus: 'idle',
    waveStartedAt: null,
    waveExpiresAt: null,

    pickupLat,
    pickupLng,
    price,
    clientName,
    pickupLabel: payload.pickupLabel ?? null,
    dropoffLabel: payload.dropoffLabel ?? null,
    dropoffLat: payload.dropoffLat ?? 0,
    dropoffLng: payload.dropoffLng ?? 0,

    createdAt: now,
    updatedAt: now,
  };

  // Idempotency: check if already in queue (prevents duplicate wave triggers)
  // PATCH-06 (RC-08): Previously only blocked when currentWave > 0, so a second
  // call arriving before processNextWave ran (wave still 0) would overwrite the doc.
  // Any existing document means the order is already queued — skip unconditionally.
  const existingDoc = await db.collection('dispatch_queue').doc(orderId).get();
  if (existingDoc.exists) {
    emitMetric('dispatch_queue_duplicate_skipped', { orderId });
    console.warn(JSON.stringify({
      tag: 'DispatchEngine',
      stage: 'enqueue',
      orderId,
      result: 'duplicate_skipped',
      existingWave: existingDoc.data()?.currentWave ?? 0,
    }));
    return;
  }

  await db.collection('dispatch_queue').doc(orderId).set(
    removeUndefinedDeep(queueEntry)
  );

  console.log('[DispatchEngine] Order enqueued', {
    order_id: orderId,
    pickup: { lat: pickupLat, lng: pickupLng },
  });

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

  await db.collection('dispatch_metrics').doc(orderId).set(
    removeUndefinedDeep(metrics)
  ).catch((err: any) => {
    // Metrics write failure is non-fatal — don't block dispatch
    console.error('[DispatchEngine] Failed to write dispatch_metrics', {
      order_id: orderId,
      error: err.message,
    });
  });

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
/**
 * Get wave config for a given wave number.
 * Waves 1-3 use DEFAULT_WAVES. Wave 4+ repeats REPEAT_WAVE.
 */
function getWaveConfig(waveNum: number): { wave: typeof DEFAULT_WAVES[0]; isRepeat: boolean } | null {
  if (waveNum <= DEFAULT_WAVES.length) {
    return { wave: DEFAULT_WAVES[waveNum - 1], isRepeat: false };
  }
  // Wave 4+: repeat
  return { wave: { ...REPEAT_WAVE, round: waveNum }, isRepeat: true };
}

export async function processNextWave(orderId: string): Promise<void> {
  const queueRef = db.collection('dispatch_queue').doc(orderId);

  try {
    const iAmTheWinner = await db.runTransaction(async (transaction) => {
      const queueDoc = await transaction.get(queueRef);

      if (!queueDoc.exists) return false;

      const queueData = queueDoc.data() as DispatchQueueEntry;
      const nextWaveNum = queueData.currentWave + 1;

      // Get wave config (waves 1-3 from DEFAULT_WAVES, 4+ repeats REPEAT_WAVE)
      const waveConfig = getWaveConfig(nextWaveNum);
      if (!waveConfig) {
        emitMetric('wave_all_exhausted', { orderId });
        return false;
      }

      // Atomic guard — only one concurrent caller proceeds
      if (queueData.waveStatus === 'sending') {
        console.warn(JSON.stringify({
          tag: 'DispatchEngine',
          stage: 'wave_start',
          orderId,
          result: 'skipped_already_sending',
        }));
        return false;
      }

      const wave = waveConfig.wave;
      const now = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromMillis(
        now.toMillis() + wave.ttl * 1000
      );

      transaction.update(queueRef, {
        currentWave: nextWaveNum,
        waveStatus: 'sending',
        waveStartedAt: now,
        waveExpiresAt: expiresAt,
        updatedAt: now,
      });

      emitMetric('wave_creation_started', { orderId, wave: nextWaveNum });
      return true;
    });

    if (!iAmTheWinner) return;

    // Send offers (only the winner reaches here)
    await sendWaveOffers(orderId);
    emitMetric('wave_creation_succeeded', { orderId });

    await db.collection('dispatch_queue').doc(orderId)
      .update({ waveStatus: 'sent' })
      .catch(() => {}); // non-fatal

    // Schedule precise Cloud Task for wave expiration
    const freshQueue = await db.collection('dispatch_queue').doc(orderId).get();
    if (freshQueue.exists) {
      const freshData = freshQueue.data() as DispatchQueueEntry;
      const currentWaveConfig = getWaveConfig(freshData.currentWave);
      if (currentWaveConfig) {
        await scheduleWaveExpirationTask(orderId, currentWaveConfig.wave.ttl).catch((err: any) => {
          console.warn(JSON.stringify({
            tag: 'DispatchEngine',
            stage: 'wave_task_schedule_failed',
            orderId,
            error: err.message,
          }));
        });
      }
    }

  } catch (error: any) {
    emitMetric('wave_creation_failed', { orderId, error: error.message });
    console.error(JSON.stringify({
      tag: 'DispatchEngine',
      stage: 'wave_process',
      orderId,
      result: 'exception',
      error: error.message,
    }));
    await db.collection('dispatch_queue').doc(orderId)
      .update({ waveStatus: 'idle' })
      .catch(() => {});
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
  const waveConfig = getWaveConfig(queueData.currentWave);
  if (!waveConfig) return;
  const wave = waveConfig.wave;

  // Find eligible drivers
  const eligibleDrivers = await findEligibleDrivers(
    queueData.pickupLat,
    queueData.pickupLng,
    wave.maxDistance,
    wave.maxDrivers
  );

  if (eligibleDrivers.length === 0) {
    emitMetric('wave_no_eligible_drivers', { orderId, wave: queueData.currentWave });
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
    // FIX-R2: Include round in offerId to prevent cross-wave dedup collisions.
    // Old format: orderId_driverId (collided when same driver re-offered in wave 4+)
    // New format: orderId_driverId_w{round}
    const offerId = `${orderId}_${driver.driverId}_w${queueData.currentWave}`;

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
    batch.set(db.collection('dispatch_offers').doc(offerId), removeUndefinedDeep(offer));

    // Update driver state (mark as having active offer)
    batch.set(db.collection('driver_dispatch_state').doc(driver.driverId), removeUndefinedDeep({
      driverId: driver.driverId,
      activeOfferId: offerId,
      lastOfferAt: now,
      updatedAt: now,
    }), { merge: true });
  }

  // Update metrics (non-fatal if metrics doc missing)
  try {
    batch.update(db.collection('dispatch_metrics').doc(orderId), {
      [`waveMetrics`]: admin.firestore.FieldValue.arrayUnion(removeUndefinedDeep({
        round: queueData.currentWave,
        driversSent: eligibleDrivers.length,
        rejections: 0,
        expirations: 0,
        startedAt: now,
        completedAt: null,
      })),
      totalDriversNotified: admin.firestore.FieldValue.increment(eligibleDrivers.length),
    });
  } catch (metricsErr: any) {
    console.warn('[DispatchEngine] Metrics update skipped', {
      order_id: orderId,
      error: metricsErr.message,
    });
  }

  // Update queue total offers sent
  batch.update(db.collection('dispatch_queue').doc(orderId), {
    totalOffersSent: admin.firestore.FieldValue.increment(eligibleDrivers.length),
  });

  await withRetry(() => batch.commit(), { label: 'sendWaveOffers_batch', orderId });

  console.log('[DispatchEngine] Offers created', {
    order_id: orderId,
    wave: queueData.currentWave,
    offers_sent: offers.length,
  });

  // Send FCM notifications using queue data as single source of truth
  // NEVER passes raw order data — only normalized queueData
  sendWaveNotifications(orderId, offers, eligibleDrivers, queueData);
}

/**
 * Send FCM notifications for wave offers.
 *
 * ARCHITECTURE: Uses dispatch_queue entry as single source of truth.
 * NEVER fetches raw order documents.
 *
 * SAFETY:
 * - Guards driver[i] index mismatch
 * - Never throws (logs + skips on per-driver failure)
 * - Aggregates failure metrics per wave
 */
async function sendWaveNotifications(
  orderId: string,
  offers: DispatchOffer[],
  drivers: EligibleDriver[],
  queueData: DispatchQueueEntry
): Promise<void> {
  let successCount = 0;
  let failCount = 0;

  const notificationPromises = offers.map(async (offer, index) => {
    // Guard: driver index mismatch
    const driver = drivers[index];
    if (!driver) {
      failCount++;
      console.error(JSON.stringify({
        tag: 'DispatchEngine',
        stage: 'notification',
        orderId,
        offerId: offer.offerId,
        result: 'driver_index_mismatch',
        index,
        driversLength: drivers.length,
        offersLength: offers.length,
      }));
      return;
    }

    // sendOfferNotification NEVER throws — always returns structured result
    const result = await sendOfferNotification(offer, queueData, driver.fcmToken);

    if (result.success) {
      successCount++;
      // Update offer with FCM message ID (non-fatal if fails)
      await db.collection('dispatch_offers').doc(offer.offerId).update({
        fcmMessageId: result.messageId,
      }).catch((err: any) => {
        console.warn('[DispatchEngine] Failed to update fcmMessageId', {
          offer_id: offer.offerId,
          error: err.message,
        });
      });
    } else {
      failCount++;
      console.warn(JSON.stringify({
        tag: 'DispatchEngine',
        stage: 'notification',
        orderId,
        offerId: offer.offerId,
        driverId: offer.driverId,
        result: 'notification_failed',
        error: result.error,
      }));
    }
  });

  await Promise.allSettled(notificationPromises);

  // Aggregated wave notification metrics
  console.log(JSON.stringify({
    tag: 'DispatchEngine',
    stage: 'wave_notifications_summary',
    orderId,
    wave: queueData.currentWave,
    totalOffers: offers.length,
    successCount,
    failCount,
  }));
}

// ============================================================================
// WAVE EXPIRATION HANDLER
// ============================================================================

// ============================================================================
// CLOUD TASKS — PRECISE WAVE EXPIRATION SCHEDULING
// ============================================================================

/**
 * Schedule a Cloud Task to process wave expiration for a specific order.
 * Fires exactly `ttlSeconds` after the wave starts — eliminates the
 * up-to-60s dead time of the old 1-minute scheduler.
 */
async function scheduleWaveExpirationTask(orderId: string, ttlSeconds: number): Promise<void> {
  const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || '';
  const location = 'us-central1';
  const queue = 'wave-expiration';
  const serviceUrl = `https://${location}-${project}.cloudfunctions.net/handleWaveExpirationTask`;

  const client = new CloudTasksClient();
  const parent = client.queuePath(project, location, queue);

  const scheduleTime = new Date(Date.now() + ttlSeconds * 1000);
  const serviceAccountEmail = `firebase-adminsdk-fbsvc@${project}.iam.gserviceaccount.com`;
  const task = {
    httpRequest: {
      httpMethod: 'POST' as const,
      url: serviceUrl,
      headers: { 'Content-Type': 'application/json' },
      body: Buffer.from(JSON.stringify({ orderId })).toString('base64'),
      oidcToken: {
        serviceAccountEmail,
        audience: serviceUrl,
      },
    },
    scheduleTime: {
      seconds: Math.floor(scheduleTime.getTime() / 1000),
      nanos: 0,
    },
  };

  await client.createTask({ parent, task });

  console.log(JSON.stringify({
    tag: 'DispatchEngine',
    stage: 'wave_task_scheduled',
    orderId,
    ttlSeconds,
    scheduledFor: scheduleTime.toISOString(),
  }));
}

// ============================================================================
// SINGLE-ORDER WAVE EXPIRATION (used by Cloud Tasks + fallback scheduler)
// ============================================================================

/**
 * Process wave expiration for a single order.
 *
 * Extracted from the batch loop so both the Cloud Task handler
 * and the fallback scheduler can call it.
 */
export async function processExpiredWavesForOrder(orderId: string): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  const queueDoc = await db.collection('dispatch_queue').doc(orderId).get();

  if (!queueDoc.exists) {
    console.log('[DispatchEngine] Order no longer in queue (already handled)', { order_id: orderId });
    return;
  }

  const queueData = queueDoc.data() as DispatchQueueEntry;

  // Guard: verify order is still in 'matching' status before processing waves.
  // Orders expired/cancelled by other functions remain orphaned in dispatch_queue.
  const orderDoc = await db.collection('orders').doc(orderId).get();
  if (!orderDoc.exists || orderDoc.data()?.status !== 'matching') {
    console.log('[DispatchEngine] Order no longer matching, removing from dispatch_queue', {
      order_id: orderId,
      order_status: orderDoc.data()?.status ?? 'not_found',
    });
    await dequeueOrder(orderId);
    return;
  }

  // Guard: wave currently being sent (another trigger is actively sending offers).
  // PATCH-07 (RC-07): A crashed instance leaves waveStatus === 'sending' with no
  // recovery. Detect stale 'sending' (>2 min since waveStartedAt) and reset to
  // 'idle' so the next trigger can proceed.
  if (queueData.waveStatus === 'sending') {
    const STALE_SENDING_MS = 2 * 60 * 1000; // 2 minutes
    const startedAtMs = queueData.waveStartedAt?.toMillis() ?? 0;
    const elapsedMs = now.toMillis() - startedAtMs;

    if (elapsedMs < STALE_SENDING_MS) {
      console.log('[DispatchEngine] Wave currently sending (fresh), skipping', {
        order_id: orderId,
        elapsed_ms: elapsedMs,
      });
      return;
    }

    // Stale sending state — instance likely crashed; reset and fall through.
    console.warn(JSON.stringify({
      tag: 'DispatchEngine',
      stage: 'stale_sending_recovery',
      orderId,
      elapsed_ms: elapsedMs,
      result: 'resetting_to_idle',
    }));
    await db.collection('dispatch_queue').doc(orderId)
      .update({ waveStatus: 'idle' })
      .catch(() => {}); // non-fatal; proceed anyway
  }

  // Guard: only process if the wave has actually expired
  if (queueData.waveExpiresAt && queueData.waveExpiresAt.toMillis() > now.toMillis()) {
    console.log('[DispatchEngine] Wave not yet expired, skipping', {
      order_id: orderId,
      wave: queueData.currentWave,
      expiresAt: queueData.waveExpiresAt.toDate().toISOString(),
    });
    return;
  }

  try {
    console.log('[DispatchEngine] Wave expired, moving to next', {
      order_id: orderId,
      expired_wave: queueData.currentWave,
    });

    // Mark current wave as completed in metrics (non-fatal)
    await db.collection('dispatch_metrics').doc(orderId).update({
      [`waveMetrics.${queueData.currentWave - 1}.completedAt`]: now,
    }).catch((err: any) => {
      console.warn('[DispatchEngine] Metrics update failed (non-fatal)', {
        order_id: orderId,
        error: err.message,
      });
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

    // Success — clear failure counter
    clearOrderFailure(orderId);

  } catch (err: any) {
    // Per-order circuit breaker
    const failCount = recordOrderFailure(orderId);
    recordGlobalFailure();

    console.error(JSON.stringify({
      tag: 'DispatchEngine',
      stage: 'expired_wave_processing',
      orderId,
      result: 'exception',
      consecutiveFailures: failCount,
      error: err.message,
    }));

    if (failCount >= ORDER_CIRCUIT_BREAKER_THRESHOLD) {
      await moveToStuckOrders(orderId, queueData, failCount, err.message);
      clearOrderFailure(orderId);
    }
  }
}

/**
 * Process expired waves (FALLBACK — safety net scheduler)
 *
 * Kept as a safety fallback in case Cloud Tasks fail to fire.
 * Now delegates per-order logic to processExpiredWavesForOrder.
 *
 * CIRCUIT BREAKERS:
 * - Per-order: after N consecutive failures, moves order to dispatch_stuck_orders
 * - Global: if failure rate exceeds threshold, pauses processing temporarily
 */
export async function processExpiredWaves(): Promise<void> {
  // Global circuit breaker check
  if (isGlobalCircuitOpen()) {
    console.warn(JSON.stringify({
      tag: 'CircuitBreaker',
      result: 'global_circuit_open_skipping',
      reopensAt: new Date(globalCircuitOpenUntil).toISOString(),
    }));
    return;
  }

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

  console.log('[DispatchEngine] Processing expired waves (fallback)', { count: expiredSnapshot.size });

  const promises = expiredSnapshot.docs.map((doc) => processExpiredWavesForOrder(doc.id));
  await Promise.allSettled(promises);
}

/**
 * Move a repeatedly failing order to dispatch_stuck_orders.
 * Removes from dispatch_queue to prevent infinite retry loops.
 */
async function moveToStuckOrders(
  orderId: string,
  queueData: DispatchQueueEntry,
  failCount: number,
  lastError: string
): Promise<void> {
  try {
    await db.collection('dispatch_stuck_orders').doc(orderId).set(removeUndefinedDeep({
      orderId,
      currentWave: queueData.currentWave,
      totalOffersSent: queueData.totalOffersSent,
      consecutiveFailures: failCount,
      lastError,
      stuckAt: admin.firestore.Timestamp.now(),
      pickupLat: queueData.pickupLat,
      pickupLng: queueData.pickupLng,
      price: queueData.price,
    }));

    await db.collection('dispatch_queue').doc(orderId).delete();

    emitMetric('wave_creation_failed' as DispatchMetricName, { orderId, reason: 'circuit_breaker_tripped' });

    console.error(JSON.stringify({
      tag: 'CircuitBreaker',
      level: 'CRITICAL',
      result: 'order_moved_to_stuck',
      orderId,
      consecutiveFailures: failCount,
      lastError,
    }));
  } catch (stuckErr: any) {
    console.error(JSON.stringify({
      tag: 'CircuitBreaker',
      result: 'stuck_order_write_failed',
      orderId,
      error: stuckErr.message,
    }));
  }
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

        // Guard: driver already has an active order (different from this one)
        if (state.activeOrderId && state.activeOrderId !== offer.orderId) {
          return { success: false, error: 'driver_has_active_order' };
        }

        // Guard: acceptance lock still held
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

      // 4. Update metrics — use set+merge so acceptance succeeds even if
      //    the metrics doc was never created (enqueue race / legacy order).
      const metricsRef = db.collection('dispatch_metrics').doc(offer.orderId);
      const createdAtMs = orderData.createdAt?.toMillis?.() ?? Date.now();
      transaction.set(metricsRef, {
        acceptedByDriverId: driverId,
        acceptedAtWave: offer.round,
        acceptedAt: now,
        timeToAcceptSeconds: Math.floor((now.toMillis() - createdAtMs) / 1000),
      }, { merge: true });

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

      // Update metrics — set+merge to tolerate missing doc
      const metricsRef = db.collection('dispatch_metrics').doc(offer.orderId);
      transaction.set(metricsRef, {
        [`waveMetrics.${offer.round - 1}.rejections`]: admin.firestore.FieldValue.increment(1),
      }, { merge: true });
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
