import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

/**
 * P0-FATAL FIX: Secure Driver Tracking
 * Copies driver location from `driver_locations/{driverId}` to `orders/{orderId}`.
 * This allows clients to track drivers via the Order document without
 * giving them direct access to the driver's raw location stream.
 */
export const updateOrderLocation = functions.firestore
    .document('driver_locations/{driverId}')
    .onUpdate(async (change, context) => {
        const driverId = context.params.driverId;
        const newData = change.after.data();
        const oldData = change.before.data();

        // Optimization: Skip if location hasn't changed significantly or is invalid
        if (!newData || !newData.lat || !newData.lng) return null;

        // Skip if timestamp hasn't changed (deduplication)
        if (oldData && oldData.updatedAt && newData.updatedAt && oldData.updatedAt.isEqual(newData.updatedAt)) {
            return null;
        }

        const firestore = admin.firestore();

        try {
            // Find active orders for this driver
            // We only care about orders in 'accepted' or 'onRoute' status
            const ordersSnapshot = await firestore
                .collection('orders')
                .where('assignedDriverId', '==', driverId)
                .where('status', 'in', ['accepted', 'onRoute'])
                .get();

            if (ordersSnapshot.empty) {
                return null;
            }

            // Prepare location object for the order
            const driverLocation = {
                lat: newData.lat,
                lng: newData.lng,
                heading: newData.heading || 0,
                speed: newData.speed || 0,
                updatedAt: newData.updatedAt || admin.firestore.FieldValue.serverTimestamp(),
            };

            // Batch update all active orders
            const batch = firestore.batch();

            ordersSnapshot.docs.forEach((doc) => {
                batch.update(doc.ref, {
                    driverLocation: driverLocation
                });
            });

            await batch.commit();

            // console.log(`Updated location for ${ordersSnapshot.size} active orders for driver ${driverId}`);
        } catch (error) {
            console.error(`Error updating order location for driver ${driverId}:`, error);
        }

        return null;
    });
