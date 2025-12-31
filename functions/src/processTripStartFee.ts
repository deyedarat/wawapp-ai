/**
 * Cloud Function: Trip Start Fee Deduction
 * 
 * Phase C: When an order transitions from accepted → onRoute, enforce exclusivity 
 * and deduct a 10% trip start fee from the assigned driver's wallet atomically and idempotently.
 * 
 * Rules:
 * - Started = status becomes 'onRoute'
 * - Fee = 10% of order.price (rounded to nearest integer)
 * - No Refund: if trip cancelled after fee deduction, do not refund
 * - If insufficient balance: block transition and notify driver
 * 
 * Triggers on: orders/{orderId} onUpdate
 * 
 * Author: WawApp Development Team (Phase C Implementation)
 * Last Updated: 2025-12-28
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Calculate trip start fee (10% of order price, rounded to nearest integer)
 */
function calculateTripStartFee(orderPrice: number): number {
  return Math.round(orderPrice * 0.1);
}

/**
 * Send insufficient balance notification to driver
 */
async function sendInsufficientBalanceNotification(
  driverId: string,
  orderId: string,
  requiredFee: number
): Promise<void> {
  try {
    const driverDoc = await admin
      .firestore()
      .collection('drivers')
      .doc(driverId)
      .get();

    if (!driverDoc.exists) {
      console.warn('[TripStartFee] Driver not found for notification', { driver_id: driverId });
      return;
    }

    const driverData = driverDoc.data();
    const fcmToken = driverData?.fcmToken as string | undefined;

    if (!fcmToken) {
      console.log('[TripStartFee] No FCM token for driver', { driver_id: driverId });
      return;
    }

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: 'رصيد غير كافي',
        body: `تحتاج إلى ${requiredFee} أوقية لبدء الرحلة. يرجى شحن محفظتك.`,
      },
      data: {
        notificationType: 'insufficient_balance',
        orderId: orderId,
        requiredFee: String(requiredFee),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'wallet_notifications',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);

    console.log('[TripStartFee] Insufficient balance notification sent', {
      driver_id: driverId,
      order_id: orderId,
      required_fee: requiredFee,
    });
  } catch (error) {
    console.error('[TripStartFee] Failed to send insufficient balance notification', {
      driver_id: driverId,
      order_id: orderId,
      error: error,
    });
  }
}

/**
 * Cloud Function: Handle trip start fee deduction
 */
export const processTripStartFee = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const orderId = context.params.orderId;

    const beforeStatus = beforeData.status as string;
    const afterStatus = afterData.status as string;
    const assignedDriverId = afterData.assignedDriverId as string | null;

    // Check if order transitioned from accepted → onRoute
    const isStartingTrip = 
      beforeStatus === 'accepted' && 
      afterStatus === 'onRoute' && 
      assignedDriverId !== null;

    if (!isStartingTrip) {
      return null;
    }

    console.log('[TripStartFee] Trip starting, processing fee deduction', {
      order_id: orderId,
      driver_id: assignedDriverId,
      order_price: afterData.price,
    });

    const orderPrice = afterData.price as number;
    const tripStartFee = calculateTripStartFee(orderPrice);
    const ledgerDocId = `${orderId}_start_fee`;

    console.log('[TripStartFee] Calculated fee', {
      order_id: orderId,
      order_price: orderPrice,
      trip_start_fee: tripStartFee,
      ledger_doc_id: ledgerDocId,
    });

    try {
      await admin.firestore().runTransaction(async (transaction) => {
        // Check idempotency: if ledger doc exists, fee already deducted
        const ledgerRef = admin.firestore().collection('transactions').doc(ledgerDocId);
        const existingLedger = await transaction.get(ledgerRef);

        if (existingLedger.exists) {
          console.log('[TripStartFee] Fee already deducted (idempotent)', {
            order_id: orderId,
            ledger_doc_id: ledgerDocId,
          });
          return;
        }

        // Get driver's wallet
        const walletRef = admin.firestore().collection('wallets').doc(assignedDriverId);
        const walletDoc = await transaction.get(walletRef);

        if (!walletDoc.exists) {
          throw new Error(`Driver wallet not found: ${assignedDriverId}`);
        }

        const walletData = walletDoc.data();
        const currentBalance = walletData?.balance || 0;

        // Check if sufficient balance
        if (currentBalance < tripStartFee) {
          console.warn('[TripStartFee] Insufficient balance, reverting order status', {
            order_id: orderId,
            driver_id: assignedDriverId,
            current_balance: currentBalance,
            required_fee: tripStartFee,
          });

          // P0-7 FIX: Check loop guard to prevent infinite loop
          const revertCount = afterData.feeRevertCount || 0;
          
          if (revertCount >= 3) {
            // P0-7 FIX: Too many reverts, cancel order instead
            transaction.update(change.after.ref, {
              status: 'cancelled',
              cancellationReason: 'Insufficient driver wallet balance after multiple attempts',
              cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            
            console.error('[TripStartFee] Order cancelled due to repeated insufficient balance', {
              order_id: orderId,
              driver_id: assignedDriverId,
              revert_count: revertCount,
            });
          } else {
            // P0-7 FIX: Revert with counter increment
            transaction.update(change.after.ref, {
              status: 'accepted',
              feeRevertCount: admin.firestore.FieldValue.increment(1),
              lastFeeRevertAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          // Send notification to driver (outside transaction)
          setImmediate(() => {
            sendInsufficientBalanceNotification(assignedDriverId, orderId, tripStartFee);
          });

          return;
        }

        // Deduct fee from wallet
        transaction.update(walletRef, {
          balance: admin.firestore.FieldValue.increment(-tripStartFee),
          totalDebited: admin.firestore.FieldValue.increment(tripStartFee),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Create transaction record using existing schema
        transaction.set(ledgerRef, {
          id: ledgerDocId,
          walletId: assignedDriverId,
          type: 'debit',
          source: 'trip_start_fee',
          amount: tripStartFee,
          currency: 'MRU',
          orderId: orderId,
          balanceBefore: currentBalance,
          balanceAfter: currentBalance - tripStartFee,
          note: `Trip start fee for order #${orderId}`,
          metadata: {
            orderPrice,
            feeRate: 0.1,
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Add startedAt timestamp to order for exclusivity
        transaction.update(change.after.ref, {
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log('[TripStartFee] Fee deducted successfully', {
          order_id: orderId,
          driver_id: assignedDriverId,
          fee_amount: tripStartFee,
          balance_before: currentBalance,
          balance_after: currentBalance - tripStartFee,
        });

        // Log analytics event
        console.log('[Analytics] trip_start_fee_deducted', {
          order_id: orderId,
          driver_id: assignedDriverId,
          fee_amount: tripStartFee,
          order_price: orderPrice,
        });
      });

    } catch (error) {
      console.error('[TripStartFee] Transaction failed', {
        order_id: orderId,
        driver_id: assignedDriverId,
        error: error,
      });

      // If transaction fails, try to revert order status
      try {
        await change.after.ref.update({
          status: 'accepted',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log('[TripStartFee] Order status reverted due to transaction failure', {
          order_id: orderId,
        });
      } catch (revertError) {
        console.error('[TripStartFee] Failed to revert order status', {
          order_id: orderId,
          revert_error: revertError,
        });
      }
    }

    return null;
  });