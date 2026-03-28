/**
 * Cloud Function: Expire Stale Orders
 *
 * Automatically expires orders that have been in 'matching' status for more than 10 minutes
 * without being assigned to a driver.
 *
 * Runs every 2 minutes via Cloud Scheduler.
 *
 * Author: WawApp Development Team
 * Last Updated: 2025-11-20
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Constants
const EXPIRATION_TIMEOUT_MS = 10 * 60 * 1000; // 10 minutes in milliseconds
const BATCH_LIMIT = 500; // Max orders to expire per run

/**
 * Scheduled function that expires stale orders
 * Runs every 2 minutes via Cloud Scheduler
 */
export const expireStaleOrders = functions
  .region('us-central1')
  .runWith({
    timeoutSeconds: 120, // 2 minutes max execution time
    memory: '256MB',
  })
  .pubsub
  .schedule('every 2 minutes')
  .timeZone('Africa/Nouakchott') // Mauritania timezone
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const expirationThreshold = new admin.firestore.Timestamp(
      now.seconds - (EXPIRATION_TIMEOUT_MS / 1000),
      now.nanoseconds
    );

    console.log('[ExpireOrders] Function triggered at:', now.toDate().toISOString());
    console.log('[ExpireOrders] Expiration threshold:', expirationThreshold.toDate().toISOString());

    try {
      // Query for stale orders:
      // - status == 'matching' (initial state when client creates order)
      // - assignedDriverId == null (no driver has claimed it)
      // - createdAt < (now - 10 minutes)
      const staleOrdersSnapshot = await db
        .collection('orders')
        .where('status', '==', 'matching')
        .where('assignedDriverId', '==', null)
        .where('createdAt', '<', expirationThreshold)
        .limit(BATCH_LIMIT)
        .get();

      if (staleOrdersSnapshot.empty) {
        console.log('[ExpireOrders] No stale orders found.');
        return null;
      }

      console.log(`[ExpireOrders] Found ${staleOrdersSnapshot.size} stale orders to expire.`);

      // Prepare batch update
      const batch = db.batch();
      let expiredCount = 0;
      let skippedCount = 0;

      staleOrdersSnapshot.forEach((doc) => {
        const orderData = doc.data();
        const orderId = doc.id;

        // Safety check: double-verify order is still in matching status with no driver
        if (orderData.status === 'matching' && orderData.assignedDriverId === null) {
          console.log('[ExpireOrders] Expiring order', {
            order_id: orderId,
            created_at: orderData.createdAt?.toDate?.()?.toISOString() || 'unknown',
            age_minutes: Math.floor((now.seconds - (orderData.createdAt?.seconds || now.seconds)) / 60),
          });

          batch.update(doc.ref, {
            status: 'expired',
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Log analytics-style event
          console.log('[Analytics] order_expired', {
            order_id: orderId,
            owner_id: orderData.ownerId || null,
            created_at: orderData.createdAt?.toDate?.()?.toISOString() || null,
          });

          expiredCount++;
        } else {
          console.log('[ExpireOrders] Skipping order (race condition avoided)', {
            order_id: orderId,
            current_status: orderData.status,
            has_driver: orderData.assignedDriverId !== null,
          });
          skippedCount++;
        }
      });

      // Commit batch update
      if (expiredCount > 0) {
        await batch.commit();
        console.log('[ExpireOrders] Batch committed', {
          expired: expiredCount,
          skipped: skippedCount,
          total_queried: staleOrdersSnapshot.size,
        });
        
        // Log batch analytics event
        console.log('[Analytics] order_expired_batch', { count: expiredCount });
      } else {
        console.log('[ExpireOrders] No orders to expire', {
          skipped: skippedCount,
          reason: 'All orders had status/driver changes (race condition)',
        });
      }

      // Log warning if we hit the batch limit (indicates high volume of stale orders)
      if (staleOrdersSnapshot.size === BATCH_LIMIT) {
        console.warn(`[ExpireOrders] WARNING: Hit batch limit of ${BATCH_LIMIT}. More stale orders may exist. Will process in next run.`);
      }

      return { expired: expiredCount, total: staleOrdersSnapshot.size };

    } catch (error) {
      console.error('[ExpireOrders] Error expiring stale orders:', error);

      // Re-throw to mark function as failed in Cloud Functions console
      throw new functions.https.HttpsError(
        'internal',
        'Failed to expire stale orders',
        error
      );
    }
  });
