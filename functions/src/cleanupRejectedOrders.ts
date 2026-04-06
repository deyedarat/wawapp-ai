/**
 * Cloud Function: Cleanup Expired Driver Rejection Records
 *
 * Deletes driver_rejected_orders documents where expiresAt <= now.
 * Runs daily at 3:00 AM Nouakchott time.
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

export const cleanupRejectedOrders = functions
  .region('us-central1')
  .pubsub.schedule('0 3 * * *')
  .timeZone('Africa/Nouakchott')
  .onRun(async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const expiredSnapshot = await db
      .collection('driver_rejected_orders')
      .where('expiresAt', '<=', now)
      .limit(500)
      .get();

    if (expiredSnapshot.empty) {
      console.log('[CleanupRejected] No expired records.');
      return null;
    }

    const batch = db.batch();
    expiredSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    console.log(
      `[CleanupRejected] Deleted ${expiredSnapshot.size} expired records.`
    );
    return null;
  });
