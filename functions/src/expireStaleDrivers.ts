/**
 * Cloud Function: Expire Stale Drivers
 *
 * Automatically sets drivers to offline when their location becomes stale.
 * A driver with isOnline=true but no location update for 30+ minutes is
 * invisible to the dispatch engine anyway (selectors.ts LOCATION_FRESHNESS_MINUTES=30).
 * This function makes the state explicit and notifies the driver.
 *
 * Runs every 5 minutes via Cloud Scheduler.
 *
 * @author WawApp Development Team
 * @version 1.0.0
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';

// Constants
const STALE_THRESHOLD_MINUTES = 30; // Match selectors.ts LOCATION_FRESHNESS_MINUTES
const BATCH_LIMIT = 200; // Max drivers to process per run

/**
 * Scheduled function that expires stale drivers
 * Runs every 5 minutes via Cloud Scheduler
 */
export const expireStaleDrivers = functions
    .region('us-central1')
    .runWith({
        timeoutSeconds: 120,
        memory: '256MB',
    })
    .pubsub
    .schedule('every 5 minutes')
    .timeZone('Africa/Nouakchott')
    .onRun(async () => {
        const db = admin.firestore();
        const now = Date.now();
        const staleThreshold = new Date(now - STALE_THRESHOLD_MINUTES * 60 * 1000);

        console.log('[ExpireStaleDrivers] Function triggered at:', new Date(now).toISOString());
        console.log('[ExpireStaleDrivers] Stale threshold:', staleThreshold.toISOString());

        try {
            // Step 1: Find all online drivers
            const onlineDriversSnapshot = await db
                .collection('drivers')
                .where('isOnline', '==', true)
                .limit(BATCH_LIMIT)
                .get();

            if (onlineDriversSnapshot.empty) {
                console.log('[ExpireStaleDrivers] No online drivers found.');
                return null;
            }

            console.log(`[ExpireStaleDrivers] Found ${onlineDriversSnapshot.size} online drivers. Checking locations...`);

            // Step 2: Batch-fetch their locations
            const driverIds = onlineDriversSnapshot.docs.map((doc) => doc.id);
            const locationRefs = driverIds.map((id) => db.collection('driver_locations').doc(id));
            const locationDocs = await db.getAll(...locationRefs);

            // Step 3: Identify stale drivers
            const staleDrivers: Array<{ id: string; fcmToken: string | null; name: string; lastLocationAge: number }> = [];

            for (let i = 0; i < driverIds.length; i++) {
                const driverId = driverIds[i];
                const locationDoc = locationDocs[i];
                const driverData = onlineDriversSnapshot.docs[i].data();

                let isStale = false;
                let lastLocationAge = -1;

                if (!locationDoc.exists) {
                    // No location document at all — definitely stale
                    isStale = true;
                    lastLocationAge = STALE_THRESHOLD_MINUTES + 1;
                } else {
                    const locationData = locationDoc.data()!;
                    const updatedAt = locationData.updatedAt;

                    if (!updatedAt) {
                        isStale = true;
                        lastLocationAge = STALE_THRESHOLD_MINUTES + 1;
                    } else {
                        // Handle both Timestamp and Date
                        const locationTime = updatedAt.toDate ? updatedAt.toDate() : new Date(updatedAt);
                        lastLocationAge = Math.floor((now - locationTime.getTime()) / 60000);
                        isStale = locationTime < staleThreshold;
                    }
                }

                if (isStale) {
                    // Check if driver has an active order — don't expire busy drivers
                    // (their location might be stale due to poor GPS during trip)
                    const hasActiveOrder = driverData.activeOrderId ||
                        (await db.collection('orders')
                            .where('assignedDriverId', '==', driverId)
                            .where('status', 'in', ['accepted', 'onRoute'])
                            .limit(1)
                            .get()).docs.length > 0;

                    if (!hasActiveOrder) {
                        staleDrivers.push({
                            id: driverId,
                            fcmToken: driverData.fcmToken || null,
                            name: driverData.name || 'سائق',
                            lastLocationAge,
                        });
                    } else {
                        console.log(`[ExpireStaleDrivers] Skipping driver ${driverId} — has active order`);
                    }
                }
            }

            if (staleDrivers.length === 0) {
                console.log('[ExpireStaleDrivers] No stale drivers found.');
                return null;
            }

            console.log(`[ExpireStaleDrivers] Found ${staleDrivers.length} stale driver(s) to set offline.`);

            // Step 4: Set them offline in a batch
            const batch = db.batch();

            for (const driver of staleDrivers) {
                const driverRef = db.collection('drivers').doc(driver.id);
                batch.update(driverRef, {
                    isOnline: false,
                    lastOfflineAt: admin.firestore.FieldValue.serverTimestamp(),
                    offlineReason: 'stale_location_auto_expired',
                });

                console.log('[ExpireStaleDrivers] Setting offline:', {
                    driver_id: driver.id,
                    name: driver.name,
                    location_age_minutes: driver.lastLocationAge,
                });
            }

            await batch.commit();

            // Step 5: Send a single FCM notification to each expired driver
            const notifications = staleDrivers
                .filter((d) => d.fcmToken)
                .map((driver) => {
                    const message: admin.messaging.Message = {
                        token: driver.fcmToken!,
                        data: {
                            notificationType: 'auto_offline',
                            type: 'auto_offline',
                            title: 'تم إيقاف اتصالك تلقائياً',
                            body: 'لم يتم تحديث موقعك لأكثر من 30 دقيقة. افتح التطبيق واضغط "متصل" لاستقبال الطلبات.',
                        },
                        android: {
                            priority: 'high',
                            notification: {
                                title: 'تم إيقاف اتصالك تلقائياً',
                                body: 'افتح التطبيق واضغط "متصل" لاستقبال الطلبات.',
                                channelId: 'order_updates_v10',
                            },
                        },
                    };
                    return admin.messaging().send(message).catch((err) => {
                        console.warn(`[ExpireStaleDrivers] FCM failed for ${driver.id}:`, err.message);
                        return null;
                    });
                });

            await Promise.all(notifications);

            console.log('[ExpireStaleDrivers] Done.', {
                expired: staleDrivers.length,
                notified: notifications.length,
            });

            return { expired: staleDrivers.length, notified: notifications.length };
        } catch (error) {
            console.error('[ExpireStaleDrivers] Error:', error);
            throw new functions.https.HttpsError('internal', 'Failed to expire stale drivers', error);
        }
    });
