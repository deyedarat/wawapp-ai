import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

/**
 * One-time setup: creates app_config documents for driver_app and client_app.
 * Call once via: https://<region>-wawapp-952d6.cloudfunctions.net/initAppConfig
 * Requires admin auth token in header: Authorization: Bearer <token>
 */
export const initAppConfig = onRequest(
  { cors: true },
  async (req, res) => {
    // Verify admin auth
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    try {
      const token = authHeader.split('Bearer ')[1];
      const decoded = await admin.auth().verifyIdToken(token);
      if (!decoded.isAdmin) {
        res.status(403).json({ error: 'Admin only' });
        return;
      }
    } catch {
      res.status(401).json({ error: 'Invalid token' });
      return;
    }

    const db = admin.firestore();
    const configs = [
      {
        id: 'driver_app',
        data: {
          minVersion: '1.0.1',
          latestVersion: '1.0.1',
          downloadUrl: 'https://wawapp-downloads.web.app/downloads/wawapp-driver.apk',
          updateDeadline: null,
          forceUpdate: false,
          updateMessage: 'نسخة جديدة متاحة',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {
        id: 'client_app',
        data: {
          minVersion: '1.0.0',
          latestVersion: '1.0.0',
          downloadUrl: '',
          updateDeadline: null,
          forceUpdate: false,
          updateMessage: 'نسخة جديدة متاحة',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
    ];

    const results: Record<string, string> = {};
    for (const config of configs) {
      const ref = db.collection('app_config').doc(config.id);
      const snap = await ref.get();
      if (snap.exists) {
        results[config.id] = 'already exists — skipped';
      } else {
        await ref.set(config.data);
        results[config.id] = 'created';
      }
    }

    res.json({ success: true, results });
  }
);
