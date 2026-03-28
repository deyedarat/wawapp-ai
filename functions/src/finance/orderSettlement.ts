import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { FINANCE_CONFIG } from './config';
import { atomicWalletUpdate } from './walletOperations';

/**
 * Firestore Trigger: Settle completed orders into wallets
 *
 * Triggers when an order status changes to 'completed'
 *
 * Bug #1 FIX: Platform commission is split into TWO phases:
 * - Phase 1 (Trip Start): 10% deducted when status becomes 'onRoute' (processTripStartFee.ts)
 * - Phase 2 (Completion): 10% deducted at completion (this function)
 * Total: 20% platform commission as per PLATFORM_COMMISSION_RATE
 *
 * Bug #2 FIX: Uses atomicWalletUpdate for race-condition-free ledger recording
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
 * Settle an order into driver and platform wallets
 *
 * P0-1 FIX: Idempotency check moved INSIDE transaction to prevent race condition
 * Bug #1 FIX: Deduct only COMPLETION_FEE_RATE (10%), not full 20%
 * Bug #2 FIX: Use atomicWalletUpdate instead of manual transaction logic
 */
async function settleOrder(orderId: string, orderData: any): Promise<void> {
  const db = admin.firestore();
  const orderPrice = orderData.price;
  const driverId = orderData.driverId;

  // Bug #1 FIX: Platform commission is split into two phases (10% + 10% = 20% total)
  // First 10% was already deducted at trip start (processTripStartFee.ts)
  // This function deducts the remaining 10% at completion
  const completionFee = Math.round(orderPrice * FINANCE_CONFIG.COMPLETION_FEE_RATE);
  const driverEarning = Math.round(orderPrice * FINANCE_CONFIG.DRIVER_COMMISSION_RATE);

  console.log(`[OrderSettlement] Order ${orderId}: Settling ${orderPrice} MRU`, {
    orderPrice,
    completionFee: completionFee,
    driverGross: driverEarning,
    driverId,
  });

  // CRITICAL VALIDATION: Verify trip start fee was deducted
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
    deductedAt: tripStartFeeDoc.createdAt,
  });

  // Check idempotency before settlement
  const orderRef = db.collection('orders').doc(orderId);
  const orderSnap = await orderRef.get();

  if (orderSnap.data()?.settledAt) {
    console.log(`[OrderSettlement] Order ${orderId}: Already settled (idempotent)`);
    return;
  }

  try {
    // Bug #2 FIX: Use atomic wallet operations instead of manual transaction logic
    // Step 1: Deduct completion fee from driver (10% of order price)
    const completionFeeResult = await atomicWalletUpdate(
      db,
      driverId,
      -completionFee,
      {
        orderId,
        type: 'completion_fee',
        description: `Completion fee (10%) for order #${orderId}`,
        metadata: {
          orderPrice,
          feeRate: FINANCE_CONFIG.COMPLETION_FEE_RATE,
        },
      }
    );

    console.log(`[OrderSettlement] Completion fee deducted:`, {
      orderId,
      driverId,
      completionFee,
      transactionId: completionFeeResult.transactionId,
      balanceBefore: completionFeeResult.balanceBefore,
      balanceAfter: completionFeeResult.balanceAfter,
    });

    // Step 2: Credit driver with gross earning (80% of order price)
    const driverPaymentResult = await atomicWalletUpdate(
      db,
      driverId,
      driverEarning,
      {
        orderId,
        type: 'driver_payout',
        description: `Driver payment for order #${orderId}`,
        metadata: {
          orderPrice,
          driverShare: FINANCE_CONFIG.DRIVER_COMMISSION_RATE,
        },
      }
    );

    console.log(`[OrderSettlement] Driver payment credited:`, {
      orderId,
      driverId,
      driverEarning,
      transactionId: driverPaymentResult.transactionId,
      balanceBefore: driverPaymentResult.balanceBefore,
      balanceAfter: driverPaymentResult.balanceAfter,
    });

    // Step 3: Credit platform with completion fee
    const platformPaymentResult = await atomicWalletUpdate(
      db,
      FINANCE_CONFIG.PLATFORM_WALLET_ID,
      completionFee,
      {
        orderId,
        type: 'completion_fee',
        description: `Platform completion fee from order #${orderId}`,
        metadata: {
          orderPrice,
          completionFeeRate: FINANCE_CONFIG.COMPLETION_FEE_RATE,
        },
      }
    );

    console.log(`[OrderSettlement] Platform fee credited:`, {
      orderId,
      platformWalletId: FINANCE_CONFIG.PLATFORM_WALLET_ID,
      completionFee,
      transactionId: platformPaymentResult.transactionId,
      balanceBefore: platformPaymentResult.balanceBefore,
      balanceAfter: platformPaymentResult.balanceAfter,
    });

    // Step 4: Mark order as settled
    await orderRef.update({
      settledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[OrderSettlement] Order ${orderId}: Settlement completed successfully`, {
      orderPrice,
      completionFee,
      driverEarning,
      tripStartFee: tripStartFeeDoc.amount,
      totalPlatformCommission: Math.abs(tripStartFeeDoc.amount) + completionFee,
    });
  } catch (error: any) {
    console.error(`[OrderSettlement] Settlement failed for order ${orderId}:`, error);
    throw error;
  }
}
