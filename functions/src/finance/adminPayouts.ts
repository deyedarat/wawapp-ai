import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { FINANCE_CONFIG, PayoutMethod, PayoutStatus } from './config';

interface CreatePayoutRequest {
  driverId: string;
  amount: number;
  method: PayoutMethod;
  recipientInfo?: {
    bankName?: string;
    accountNumber?: string;
    accountName?: string;
    phoneNumber?: string;
    email?: string;
  };
  note?: string;
}

interface UpdatePayoutStatusRequest {
  payoutId: string;
  newStatus: PayoutStatus;
  note?: string;
}

/**
 * Cloud Function: Create payout request
 * Admin-only function to create a payout request for a driver
 */
export const adminCreatePayoutRequest = functions.https.onCall(
  async (
    data: CreatePayoutRequest,
    context: functions.https.CallableContext
  ): Promise<{ payoutId: string; message: string }> => {
    // Verify admin authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to create payouts.'
      );
    }

    const isAdmin = context.auth.token.isAdmin === true;
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can create payout requests.'
      );
    }

    // Validate input
    const { driverId, amount, method, recipientInfo, note } = data;

    if (!driverId || !amount || !method) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'driverId, amount, and method are required.'
      );
    }

    if (amount < FINANCE_CONFIG.MIN_PAYOUT_AMOUNT) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Payout amount must be at least ${FINANCE_CONFIG.MIN_PAYOUT_AMOUNT} MRU.`
      );
    }

    if (amount > FINANCE_CONFIG.MAX_PAYOUT_AMOUNT) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Payout amount cannot exceed ${FINANCE_CONFIG.MAX_PAYOUT_AMOUNT} MRU.`
      );
    }

    const db = admin.firestore();

    try {
      let payoutId: string = '';

      await db.runTransaction(async (transaction) => {
        // 1. Get driver wallet
        const walletRef = db.collection('wallets').doc(driverId);
        const walletSnap = await transaction.get(walletRef);

        if (!walletSnap.exists) {
          throw new functions.https.HttpsError(
            'not-found',
            `Wallet not found for driver ${driverId}.`
          );
        }

        const wallet = walletSnap.data()!;
        const availableBalance = wallet.balance - (wallet.pendingPayout || 0);

        if (amount > availableBalance) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            `Insufficient balance. Available: ${availableBalance} MRU, Requested: ${amount} MRU.`
          );
        }

        // 2. Create payout record
        const payoutRef = db.collection('payouts').doc();
        payoutId = payoutRef.id;

        transaction.set(payoutRef, {
          id: payoutId,
          driverId,
          walletId: driverId,
          amount,
          currency: FINANCE_CONFIG.DEFAULT_CURRENCY,
          method,
          status: 'requested' as PayoutStatus,
          requestedByAdminId: context.auth!.uid,
          recipientInfo: recipientInfo || null,
          note: note || null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 3. Increment pendingPayout
        transaction.update(walletRef, {
          pendingPayout: admin.firestore.FieldValue.increment(amount),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 4. Log admin action
        if (FINANCE_CONFIG.ENABLE_AUDIT_LOGGING) {
          const actionRef = db.collection('admin_actions').doc();
          transaction.set(actionRef, {
            action: 'createPayoutRequest',
            performedBy: context.auth!.uid,
            driverId,
            payoutId,
            amount,
            method,
            performedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      return {
        payoutId,
        message: `Payout request created successfully for ${amount} MRU.`,
      };
    } catch (error: any) {
      console.error('Error creating payout request:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        'internal',
        `Failed to create payout request: ${error.message}`
      );
    }
  }
);

/**
 * Cloud Function: Update payout status
 * Admin-only function to update payout status (approve, complete, reject)
 */
export const adminUpdatePayoutStatus = functions.https.onCall(
  async (
    data: UpdatePayoutStatusRequest,
    context: functions.https.CallableContext
  ): Promise<{ message: string }> => {
    // Verify admin authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to update payouts.'
      );
    }

    const isAdmin = context.auth.token.isAdmin === true;
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can update payout status.'
      );
    }

    // Validate input
    const { payoutId, newStatus, note } = data;

    if (!payoutId || !newStatus) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'payoutId and newStatus are required.'
      );
    }

    const validStatuses: PayoutStatus[] = ['requested', 'approved', 'processing', 'completed', 'rejected'];
    if (!validStatuses.includes(newStatus)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Invalid status. Must be one of: ${validStatuses.join(', ')}`
      );
    }

    const db = admin.firestore();

    try {
      if (newStatus === 'completed') {
        await completePayout(db, payoutId, context.auth!.uid, note);
      } else if (newStatus === 'rejected') {
        await rejectPayout(db, payoutId, context.auth!.uid, note);
      } else {
        // Simple status update (approved, processing)
        await simpleStatusUpdate(db, payoutId, newStatus, context.auth!.uid, note);
      }

      return { message: `Payout status updated to ${newStatus}.` };
    } catch (error: any) {
      console.error('Error updating payout status:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        'internal',
        `Failed to update payout status: ${error.message}`
      );
    }
  }
);

/**
 * Complete a payout: debit wallet, create transaction, update status
 */
async function completePayout(
  db: admin.firestore.Firestore,
  payoutId: string,
  adminId: string,
  note?: string
): Promise<void> {
  await db.runTransaction(async (transaction) => {
    // 1. Get payout
    const payoutRef = db.collection('payouts').doc(payoutId);
    const payoutSnap = await transaction.get(payoutRef);

    if (!payoutSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payout not found.');
    }

    const payout = payoutSnap.data()!;

    // Check if already completed (idempotency)
    if (payout.status === 'completed') {
      console.log(`Payout ${payoutId} already completed`);
      return;
    }

    // Check if already rejected
    if (payout.status === 'rejected') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Cannot complete a rejected payout.'
      );
    }

    // 2. Get wallet
    const walletRef = db.collection('wallets').doc(payout.driverId);
    const walletSnap = await transaction.get(walletRef);

    if (!walletSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Wallet not found.');
    }

    const wallet = walletSnap.data()!;
    const currentBalance = wallet.balance || 0;

    // Validate balance
    if (currentBalance < payout.amount) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient balance: ${currentBalance} MRU < ${payout.amount} MRU.`
      );
    }

    // 3. Create debit transaction
    const txnRef = db.collection('transactions').doc();
    transaction.set(txnRef, {
      id: txnRef.id,
      walletId: payout.driverId,
      type: 'debit',
      source: 'payout',
      amount: payout.amount,
      currency: FINANCE_CONFIG.DEFAULT_CURRENCY,
      payoutId,
      adminId,
      balanceBefore: currentBalance,
      balanceAfter: currentBalance - payout.amount,
      note: note || `Payout via ${payout.method}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Update wallet
    transaction.update(walletRef, {
      balance: admin.firestore.FieldValue.increment(-payout.amount),
      totalDebited: admin.firestore.FieldValue.increment(payout.amount),
      pendingPayout: admin.firestore.FieldValue.increment(-payout.amount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Update payout
    transaction.update(payoutRef, {
      status: 'completed',
      processedByAdminId: adminId,
      transactionId: txnRef.id,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 6. Log admin action
    if (FINANCE_CONFIG.ENABLE_AUDIT_LOGGING) {
      const actionRef = db.collection('admin_actions').doc();
      transaction.set(actionRef, {
        action: 'completePayoutRequest',
        performedBy: adminId,
        driverId: payout.driverId,
        payoutId,
        amount: payout.amount,
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}

/**
 * Reject a payout: release pending amount, update status
 */
async function rejectPayout(
  db: admin.firestore.Firestore,
  payoutId: string,
  adminId: string,
  reason?: string
): Promise<void> {
  await db.runTransaction(async (transaction) => {
    // 1. Get payout
    const payoutRef = db.collection('payouts').doc(payoutId);
    const payoutSnap = await transaction.get(payoutRef);

    if (!payoutSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payout not found.');
    }

    const payout = payoutSnap.data()!;

    // Check if already completed
    if (payout.status === 'completed') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Cannot reject a completed payout.'
      );
    }

    // Check if already rejected (idempotency)
    if (payout.status === 'rejected') {
      console.log(`Payout ${payoutId} already rejected`);
      return;
    }

    // 2. Update wallet (release pending amount)
    const walletRef = db.collection('wallets').doc(payout.driverId);
    transaction.update(walletRef, {
      pendingPayout: admin.firestore.FieldValue.increment(-payout.amount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3. Update payout
    transaction.update(payoutRef, {
      status: 'rejected',
      processedByAdminId: adminId,
      rejectionReason: reason || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Log admin action
    if (FINANCE_CONFIG.ENABLE_AUDIT_LOGGING) {
      const actionRef = db.collection('admin_actions').doc();
      transaction.set(actionRef, {
        action: 'rejectPayoutRequest',
        performedBy: adminId,
        driverId: payout.driverId,
        payoutId,
        reason: reason || null,
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}

/**
 * Simple status update (approved, processing)
 */
async function simpleStatusUpdate(
  db: admin.firestore.Firestore,
  payoutId: string,
  newStatus: PayoutStatus,
  adminId: string,
  note?: string
): Promise<void> {
  await db.runTransaction(async (transaction) => {
    const payoutRef = db.collection('payouts').doc(payoutId);
    const payoutSnap = await transaction.get(payoutRef);

    if (!payoutSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payout not found.');
    }

    transaction.update(payoutRef, {
      status: newStatus,
      processedByAdminId: adminId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log admin action
    if (FINANCE_CONFIG.ENABLE_AUDIT_LOGGING) {
      const actionRef = db.collection('admin_actions').doc();
      transaction.set(actionRef, {
        action: 'updatePayoutStatus',
        performedBy: adminId,
        payoutId,
        newStatus,
        note: note || null,
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}
