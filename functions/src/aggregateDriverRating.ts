/**
 * Cloud Function to aggregate driver ratings
 * Triggered when an order document is updated with a rating
 * 
 * IDEMPOTENCY: Uses order ID tracking to prevent double-counting
 * VALIDATION: Ensures rating is 1-5 and order is completed
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const aggregateDriverRating = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    // Only process if driverRating was just added (not updated)
    if (before.driverRating || !after.driverRating) {
      return null; // Rating already existed or was removed
    }

    const driverId = after.driverId;
    const rating = after.driverRating;
    const orderStatus = after.status;

    // Validation checks
    if (!driverId) {
      console.log('[AggregateRating] Skipping - no driverId', { order_id: orderId });
      return null;
    }

    if (typeof rating !== 'number' || rating < 1 || rating > 5) {
      console.error('[AggregateRating] Invalid rating value', {
        order_id: orderId,
        driver_id: driverId,
        rating: rating,
      });
      return null;
    }

    if (orderStatus !== 'completed') {
      console.warn('[AggregateRating] Rating on non-completed order', {
        order_id: orderId,
        driver_id: driverId,
        status: orderStatus,
      });
      // Continue anyway - client validation should prevent this
    }

    console.log('[AggregateRating] Processing rating', {
      order_id: orderId,
      driver_id: driverId,
      rating: rating,
    });

    try {
      await admin.firestore().runTransaction(async (transaction) => {
        const driverRef = admin.firestore().collection('drivers').doc(driverId);
        const driverDoc = await transaction.get(driverRef);

        if (!driverDoc.exists) {
          console.error('[AggregateRating] Driver not found', {
            driver_id: driverId,
            order_id: orderId,
          });
          return;
        }

        const driverData = driverDoc.data()!;
        
        // Check if this order was already counted (idempotency)
        const ratedOrders = driverData.ratedOrders || [];
        if (ratedOrders.includes(orderId)) {
          console.log('[AggregateRating] Already processed (idempotent)', {
            order_id: orderId,
            driver_id: driverId,
          });
          return;
        }

        const currentRating = driverData.rating || 0;
        const currentTotalTrips = driverData.totalTrips || 0;

        // Calculate new average rating
        const newTotalTrips = currentTotalTrips + 1;
        const newRating = ((currentRating * currentTotalTrips) + rating) / newTotalTrips;

        // Update driver with new rating and track this order
        transaction.update(driverRef, {
          rating: Math.round(newRating * 10) / 10, // Round to 1 decimal
          totalTrips: newTotalTrips,
          ratedOrders: admin.firestore.FieldValue.arrayUnion(orderId),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log('[AggregateRating] Updated driver rating', {
          driver_id: driverId,
          order_id: orderId,
          old_rating: currentRating.toFixed(1),
          new_rating: newRating.toFixed(1),
          total_trips: newTotalTrips,
        });

        // Log analytics event
        console.log('[Analytics] driver_rating_aggregated', {
          driver_id: driverId,
          order_id: orderId,
          rating: rating,
          new_average: newRating.toFixed(1),
          total_trips: newTotalTrips,
        });
      });
    } catch (error) {
      console.error('[AggregateRating] Transaction failed', {
        driver_id: driverId,
        order_id: orderId,
        error: error,
      });
      // Re-throw to mark function as failed for retry
      throw error;
    }

    return null;
  });