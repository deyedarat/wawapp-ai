/**
 * Cloud Function: Aggregate Notification Metrics
 *
 * Scheduled daily at 2:00 AM Riyadh time (Asia/Riyadh = UTC+3).
 * Queries notification_logs collectionGroup for yesterday's events,
 * aggregates delivery/tap/duplicate metrics, and saves to
 * notification_analytics/{YYYY-MM-DD}.
 *
 * Firestore structure read:
 *   notification_logs/{uid}/events/{eventId}
 *     - eventType: 'received' | 'displayed' | 'tapped' | 'skipped'
 *     - notificationType: 'new_order' | 'unassigned_order_reminder' | ...
 *     - escalationLevel?: 'persistent_duplicate' | 'duplicate_notification' | ...
 *     - timestamp: Timestamp
 *
 * Firestore structure written:
 *   notification_analytics/{YYYY-MM-DD}
 *     - date, totalSent, totalDelivered, totalTapped, totalDuplicates
 *     - deliveryRate, tapRate, duplicateRate (percentages)
 *     - byType: { [type]: { sent, delivered, tapped, duplicates } }
 *     - createdAt
 *
 * @author WawApp Development Team
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

const BATCH_SIZE = 500;

export const aggregateNotificationMetrics = functions
  .region('us-central1')
  .runWith({ timeoutSeconds: 300, memory: '512MB' })
  .pubsub.schedule('0 2 * * *')          // 2:00 AM daily
  .timeZone('Asia/Riyadh')
  .onRun(async (_context) => {
    const db = admin.firestore();

    // Yesterday in Riyadh (UTC+3)
    const nowUtc = new Date();
    const riyadhOffset = 3 * 60 * 60 * 1000;
    const riyadhNow = new Date(nowUtc.getTime() + riyadhOffset);
    const yesterday = new Date(riyadhNow);
    yesterday.setDate(yesterday.getDate() - 1);

    const dateStr = yesterday.toISOString().slice(0, 10); // YYYY-MM-DD

    // Day boundaries in UTC (for Firestore query)
    const dayStartRiyadh = new Date(`${dateStr}T00:00:00+03:00`);
    const dayEndRiyadh = new Date(`${dateStr}T23:59:59.999+03:00`);
    const startTs = admin.firestore.Timestamp.fromDate(dayStartRiyadh);
    const endTs = admin.firestore.Timestamp.fromDate(dayEndRiyadh);

    console.log(`[NotifMetrics] Aggregating for ${dateStr}`, {
      start: dayStartRiyadh.toISOString(),
      end: dayEndRiyadh.toISOString(),
    });

    // ── Paginated collectionGroup query ──
    interface TypeMetrics {
      sent: number;
      delivered: number;
      tapped: number;
      duplicates: number;
    }

    let totalSent = 0;
    let totalDelivered = 0;
    let totalTapped = 0;
    let totalDuplicates = 0;
    const byType: Record<string, TypeMetrics> = {};

    let lastDoc: admin.firestore.QueryDocumentSnapshot | undefined;
    let hasMore = true;

    while (hasMore) {
      let query = db
        .collectionGroup('events')
        .where('timestamp', '>=', startTs)
        .where('timestamp', '<=', endTs)
        .orderBy('timestamp')
        .limit(BATCH_SIZE);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snap = await query.get();
      hasMore = snap.size === BATCH_SIZE;
      if (snap.empty) break;
      lastDoc = snap.docs[snap.docs.length - 1];

      for (const doc of snap.docs) {
        const data = doc.data();
        const eventType = data.eventType as string | undefined;
        const notifType = (data.notificationType as string) || 'unknown';
        const escalation = data.escalationLevel as string | undefined;

        // Ensure byType bucket exists
        if (!byType[notifType]) {
          byType[notifType] = { sent: 0, delivered: 0, tapped: 0, duplicates: 0 };
        }
        const bucket = byType[notifType];

        switch (eventType) {
          case 'received':
            totalSent++;
            bucket.sent++;
            break;
          case 'displayed':
            totalDelivered++;
            bucket.delivered++;
            break;
          case 'tapped':
            totalTapped++;
            bucket.tapped++;
            break;
          case 'skipped':
            if (
              escalation === 'persistent_duplicate' ||
              escalation === 'duplicate_notification'
            ) {
              totalDuplicates++;
              bucket.duplicates++;
            }
            break;
        }
      }
    }

    // ── Compute rates ──
    const pct = (num: number, den: number) =>
      den > 0 ? Math.round((num / den) * 10000) / 100 : 0;

    const deliveryRate = pct(totalDelivered, totalSent);
    const tapRate = pct(totalTapped, totalDelivered);
    const duplicateRate = pct(totalDuplicates, totalSent);

    // ── Write to Firestore ──
    const docRef = db.collection('notification_analytics').doc(dateStr);
    await docRef.set({
      date: dateStr,
      totalSent,
      totalDelivered,
      totalTapped,
      totalDuplicates,
      deliveryRate,
      tapRate,
      duplicateRate,
      byType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[NotifMetrics] ✅ Saved notification_analytics/${dateStr}`, {
      totalSent,
      totalDelivered,
      totalTapped,
      totalDuplicates,
      deliveryRate,
      tapRate,
      duplicateRate,
      types: Object.keys(byType).length,
    });

    return null;
  });
