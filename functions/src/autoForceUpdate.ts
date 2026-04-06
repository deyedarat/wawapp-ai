import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

/**
 * Runs every hour. Checks if updateDeadline has passed for driver_app
 * and client_app. If so, sets forceUpdate = true.
 */
export const autoForceUpdate = onSchedule(
  { schedule: 'every 1 hours', timeoutSeconds: 30 },
  async () => {
    const db = admin.firestore();
    const apps = ['driver_app', 'client_app'];

    for (const appId of apps) {
      const ref = db.collection('app_config').doc(appId);
      const snap = await ref.get();
      if (!snap.exists) continue;

      const data = snap.data()!;
      if (data.forceUpdate === true) continue; // already forced

      const deadline = data.updateDeadline;
      if (!deadline) continue;

      const deadlineDate = deadline.toDate ? deadline.toDate() : new Date(deadline);
      if (new Date() >= deadlineDate) {
        await ref.update({ forceUpdate: true });
        console.log(`[autoForceUpdate] ✅ forceUpdate enabled for ${appId}`);
      }
    }
  }
);
