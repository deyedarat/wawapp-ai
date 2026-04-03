import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FINANCE_CONFIG } from './config';
import { atomicWalletUpdate } from './walletOperations';

/**
 * Firestore Trigger: Settle completed orders
 *
 * Triggers when an order status changes to 'completed'
 *
 * Commission model: 10% total, deducted ONCE at trip start (processTripStartFee.ts)
 * This function only: verifies trip start fee, credits platform wallet, marks order settled.
 *
 * IDEMPOTENT: Safe to retry, checks settledAt field
 */
export const onOrderCompleted = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const orderId = context.params.orderId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Only process when status changes TO completed
    const wasCompleted = beforeData.status === 'completed';
    const isCompleted = afterData.status === 'completed';

    if (!isCompleted || wasCompleted) {
      console.log(`Order ${orderId}: No settlement needed (status: ${beforeData.status} → ${afterData.status})`);
      return null;
    }

    // Check if already settled (idempotency)
    if (afterData.settledAt) {
      console.log(`Order ${orderId}: Already settled at ${afterData.settledAt.toDate()}`);
      return null;
    }

    // Validate order data
    if (!afterData.price || afterData.price <= 0) {
      console.error(`Order ${orderId}: Invalid price ${afterData.price}`);
      return null;
    }

    if (!afterData.driverId) {
      console.error(`Order ${orderId}: Missing driverId`);
      return null;
    }

    try {
      await settleOrder(orderId, afterData);
      console.log(`Order ${orderId}: Successfully settled`);
      return null;
    } catch (error: any) {
      console.error(`Order ${orderId}: Settlement failed:`, error);
      throw error; // Throw to trigger retry
    }
  });

/**
 * Settle a completed order
 *
 * The 10% commission was already deducted from driver at trip start (processTripStartFee.ts).
 * This function: verifies that deduction, credits platform wallet, marks order settled.
 */
async function settleOrder(orderId: string, orderData: any): Promise<void> {
  const db = admin.firestore();
  const orderPrice = orderData.price;
  const driverId = orderData.driverId;
  const tripStartFee = Math.round(orderPrice * FINANCE_CONFIG.TRIP_START_FEE_RATE);

  console.log(`[OrderSettlement] Order ${orderId}: Settling ${orderPrice} MRU`, {
    orderPrice,
    driverId,
  });

  // Verify trip start fee was deducted
  const tripStartFeeQuery = await db
    .collection('transactions')
    .where('orderId', '==', orderId)
    .where('type', '==', 'trip_start_fee')
    .limit(1)
    .get();

  if (tripStartFeeQuery.empty) {
    const errorMsg = `CRITICAL: Trip start fee not found for order ${orderId}. ` +
      `Settlement cannot proceed without confirmed trip start fee deduction.`;
    console.error(`[OrderSettlement] ${errorMsg}`);
    throw new Error(errorMsg);
  }

  const tripStartFeeDoc = tripStartFeeQuery.docs[0].data();
  console.log(`[OrderSettlement] Trip start fee verified:`, {
    orderId,
    tripStartFee: tripStartFeeDoc.amount,
  });

  // Check idempotency
  const orderRef = db.collection('orders').doc(orderId);
  const orderSnap = await orderRef.get();

  if (orderSnap.data()?.settledAt) {
    console.log(`[OrderSettlement] Order ${orderId}: Already settled (idempotent)`);
    return;
  }

  try {
    // Credit platform wallet with the commission (already deducted from driver at trip start)
    const platformPaymentResult = await atomicWalletUpdate(
      db,
      FINANCE_CONFIG.PLATFORM_WALLET_ID,
      tripStartFee,
      {
        orderId,
        type: 'completion_fee',
        description: `Platform commission (10%) from order #${orderId}`,
        metadata: {
          orderPrice,
          feeRate: FINANCE_CONFIG.TRIP_START_FEE_RATE,
        },
      }
    );

    console.log(`[OrderSettlement] Platform fee credited:`, {
      orderId,
      platformWalletId: FINANCE_CONFIG.PLATFORM_WALLET_ID,
      tripStartFee,
      transactionId: platformPaymentResult.transactionId,
    });

    // Mark order as settled
    await orderRef.update({
      settledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[OrderSettlement] Order ${orderId}: Settlement completed`, {
      orderPrice,
      totalPlatformCommission: tripStartFee,
    });
  } catch (error: any) {
    console.error(`[OrderSettlement] Settlement failed for order ${orderId}:`, error);
    throw error;
  }
}
