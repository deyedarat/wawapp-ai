import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { FINANCE_CONFIG } from './config';

/**
 * Firestore Trigger: Settle completed orders into wallets
 * 
 * Triggers when an order status changes to 'completed'
 * Credits driver wallet (80%) and platform wallet (20%)
 * Creates transaction records for audit trail
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
 */
async function settleOrder(orderId: string, orderData: any): Promise<void> {
  const db = admin.firestore();
  const orderPrice = orderData.price;
  const driverId = orderData.driverId;

  // Calculate amounts
  const platformFee = Math.round(orderPrice * FINANCE_CONFIG.PLATFORM_COMMISSION_RATE);
  const driverEarning = orderPrice - platformFee;

  console.log(`Order ${orderId}: Settling ${orderPrice} MRU (driver: ${driverEarning}, platform: ${platformFee})`);

  // Execute settlement in a transaction
  await db.runTransaction(async (transaction) => {
    // 1. Get or create driver wallet
    const driverWalletRef = db.collection('wallets').doc(driverId);
    const driverWalletSnap = await transaction.get(driverWalletRef);

    let driverBalance = 0;
    // let driverTotalCredited = 0;

    if (!driverWalletSnap.exists) {
      // Create new driver wallet
      console.log(`Creating wallet for driver ${driverId}`);
      transaction.set(driverWalletRef, {
        id: driverId,
        type: 'driver',
        ownerId: driverId,
        balance: 0,
        totalCredited: 0,
        totalDebited: 0,
        pendingPayout: 0,
        currency: FINANCE_CONFIG.DEFAULT_CURRENCY,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      driverBalance = driverWalletSnap.data()!.balance || 0;
      // driverTotalCredited = driverWalletSnap.data()!.totalCredited || 0;
    }

    // 2. Get platform wallet (should exist, but create if not)
    const platformWalletRef = db.collection('wallets').doc(FINANCE_CONFIG.PLATFORM_WALLET_ID);
    const platformWalletSnap = await transaction.get(platformWalletRef);

    let platformBalance = 0;
    // let platformTotalCredited = 0;

    if (!platformWalletSnap.exists) {
      // Create platform wallet
      console.log('Creating platform wallet');
      transaction.set(platformWalletRef, {
        id: FINANCE_CONFIG.PLATFORM_WALLET_ID,
        type: 'platform',
        ownerId: null,
        balance: 0,
        totalCredited: 0,
        totalDebited: 0,
        pendingPayout: 0,
        currency: FINANCE_CONFIG.DEFAULT_CURRENCY,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      platformBalance = platformWalletSnap.data()!.balance || 0;
      // platformTotalCredited = platformWalletSnap.data()!.totalCredited || 0;
    }

    // 3. Update driver wallet
    transaction.update(driverWalletRef, {
      balance: admin.firestore.FieldValue.increment(driverEarning),
      totalCredited: admin.firestore.FieldValue.increment(driverEarning),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Update platform wallet
    transaction.update(platformWalletRef, {
      balance: admin.firestore.FieldValue.increment(platformFee),
      totalCredited: admin.firestore.FieldValue.increment(platformFee),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Create driver transaction
    const driverTxnRef = db.collection('transactions').doc();
    transaction.set(driverTxnRef, {
      id: driverTxnRef.id,
      walletId: driverId,
      type: 'credit',
      source: 'order_settlement',
      amount: driverEarning,
      currency: FINANCE_CONFIG.DEFAULT_CURRENCY,
      orderId,
      balanceBefore: driverBalance,
      balanceAfter: driverBalance + driverEarning,
      note: `Driver earning from order #${orderId}`,
      metadata: {
        orderPrice,
        driverShare: FINANCE_CONFIG.DRIVER_COMMISSION_RATE,
        platformFee,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 6. Create platform transaction
    const platformTxnRef = db.collection('transactions').doc();
    transaction.set(platformTxnRef, {
      id: platformTxnRef.id,
      walletId: FINANCE_CONFIG.PLATFORM_WALLET_ID,
      type: 'credit',
      source: 'order_settlement',
      amount: platformFee,
      currency: FINANCE_CONFIG.DEFAULT_CURRENCY,
      orderId,
      balanceBefore: platformBalance,
      balanceAfter: platformBalance + platformFee,
      note: `Platform commission from order #${orderId}`,
      metadata: {
        orderPrice,
        platformShare: FINANCE_CONFIG.PLATFORM_COMMISSION_RATE,
        driverEarning,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 7. Mark order as settled
    const orderRef = db.collection('orders').doc(orderId);
    transaction.update(orderRef, {
      settledAt: admin.firestore.FieldValue.serverTimestamp(),
      driverEarning,
      platformFee,
    });

    console.log(`Order ${orderId}: Transaction committed successfully`);
  });
}
