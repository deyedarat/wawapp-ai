/**
 * Cloud Function to aggregate driver ratings
 * Triggered when an order document is updated with a rating
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const aggregateDriverRating = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only process if driverRating was added
    if (!before.driverRating && after.driverRating && after.driverId) {
      const driverId = after.driverId;
      const rating = after.driverRating;

      try {
        await admin.firestore().runTransaction(async (transaction) => {
          const driverRef = admin.firestore().collection('drivers').doc(driverId);
          const driverDoc = await transaction.get(driverRef);

          if (!driverDoc.exists) {
            console.warn(`Driver ${driverId} not found for rating aggregation`);
            return;
          }

          const driverData = driverDoc.data()!;
          const currentRating = driverData.rating || 0;
          const currentTotalTrips = driverData.totalTrips || 0;

          // Calculate new average rating
          const newTotalTrips = currentTotalTrips + 1;
          const newRating = ((currentRating * currentTotalTrips) + rating) / newTotalTrips;

          transaction.update(driverRef, {
            rating: Math.round(newRating * 10) / 10, // Round to 1 decimal place
            totalTrips: newTotalTrips,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`Updated driver ${driverId} rating: ${newRating.toFixed(1)} (${newTotalTrips} trips)`);
        });
      } catch (error) {
        console.error(`Error aggregating rating for driver ${driverId}:`, error);
      }
    }
  });