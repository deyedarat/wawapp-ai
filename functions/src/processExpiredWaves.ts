/**
 * processExpiredWaves — Scheduled Wave Expiration Handler
 *
 * Runs every minute to process expired dispatch waves.
 *
 * Logic:
 * - Finds all dispatch_queue entries where waveExpiresAt <= now
 * - Expires sent offers from current wave
 * - Triggers next wave
 *
 * Scheduled: every minute (* * * * *)
 * Timeout: 2 minutes
 * Memory: 256MB
 *
 * @author WawApp Development Team
 * @version 2.0.0
 */

import * as functions from 'firebase-functions/v1';
import { processExpiredWaves as processExpiredWavesEngine } from './dispatch';

export const processExpiredWaves = functions
  .region('us-central1')
  .runWith({
    timeoutSeconds: 120,
    memory: '256MB',
  })
  .pubsub.schedule('* * * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('[ProcessExpiredWaves] Function triggered', {
      timestamp: new Date().toISOString(),
    });

    try {
      await processExpiredWavesEngine();

      console.log('[ProcessExpiredWaves] Completed successfully');

      return { success: true };
    } catch (error: any) {
      console.error('[ProcessExpiredWaves] Error processing expired waves', {
        error: error.message,
        stack: error.stack,
      });

      // Re-throw to mark function as failed in Cloud Functions console
      throw new functions.https.HttpsError(
        'internal',
        'Failed to process expired waves',
        error
      );
    }
  });
