/**
 * handleWaveExpirationTask — HTTP Cloud Function called by Cloud Tasks
 *
 * Replaces the 60-second scheduler for wave expiration with precise,
 * per-order Cloud Tasks that fire exactly when a wave TTL expires.
 *
 * The old processExpiredWaves scheduler is kept as a safety fallback.
 *
 * @author WawApp Development Team
 * @version 1.0.0
 */

import * as functions from 'firebase-functions/v1';
import { processExpiredWavesForOrder } from './dispatch';

export const handleWaveExpirationTask = functions
  .region('us-central1')
  .runWith({ timeoutSeconds: 60, memory: '256MB' })
  .https.onRequest(async (req, res) => {
    // Only accept POST
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // Verify the request came from Cloud Tasks
    const taskHeader = req.headers['x-cloudtasks-taskname'];
    if (!taskHeader) {
      console.warn('[HandleWaveExpiration] Missing Cloud Tasks header');
      res.status(403).send('Forbidden');
      return;
    }

    const { orderId } = req.body;
    if (!orderId || typeof orderId !== 'string') {
      res.status(400).send('Missing orderId');
      return;
    }

    try {
      console.log('[HandleWaveExpiration] Processing wave expiration', {
        order_id: orderId,
        task_name: taskHeader,
      });

      await processExpiredWavesForOrder(orderId);

      res.status(200).send('OK');
    } catch (error: any) {
      console.error('[HandleWaveExpiration] Error processing wave expiration', {
        order_id: orderId,
        error: error.message,
      });
      // Return 500 so Cloud Tasks retries
      res.status(500).send('Internal error');
    }
  });
