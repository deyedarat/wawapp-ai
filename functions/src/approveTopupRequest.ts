/**
 * Cloud Function: Approve Driver Top-up Request
 * 
 * Phase D: Allows admins to approve driver top-up requests, crediting wallets atomically.
 * 
 * Rules:
 * - Admin-only (use existing admin auth pattern)
 * - Idempotent: if already approved, do nothing
 * - Atomic: update wallet + create transaction + update request status
 * 
 * Author: WawApp Development Team (Phase D Implementation)
 * Last Updated: 2025-12-28
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { FINANCE_CONFIG } from './finance/config';

/**
 * Callable function: Approve top-up request
 */
export const approveTopupRequest = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check admin permissions
  if (!context.auth.token.isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const adminId = context.auth.uid;
  const { requestId, notes } = data;

  if (!requestId || typeof requestId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Request ID is required');
  }

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      // Get top-up request
      const requestRef = admin.firestore().collection('topup_requests').doc(requestId);
      const requestDoc = await transaction.get(requestRef);

      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Top-up request not found');
      }

      const requestData = requestDoc.data()!;

      // Check if already processed (idempotency)
      if (requestData.status !== 'pending') {
        console.log('[ApproveTopup] Request already processed', {
          request_id: requestId,
          current_status: requestData.status,
        });
        return {
          success: true,
          message: `Request already ${requestData.status}`,
          alreadyProcessed: true,
        };
      }

      const { driverId, amount } = requestData;

      // Get or create driver wallet
      const walletRef = admin.firestore().collection('wallets').doc(driverId);
      const walletDoc = await transaction.get(walletRef);

      let currentBalance = 0;

      if (!walletDoc.exists) {
        // P0-9 FIX: Create wallet with initial balance directly (atomic)
        console.log('[ApproveTopup] Creating wallet for driver', { driver_id: driverId });
        transaction.set(walletRef, {
          id: driverId,
          type: 'driver',
          ownerId: driverId,
          balance: amount,  // P0-9 FIX: Set initial balance directly
          totalCredited: amount,  // P0-9 FIX: Set initial total
          totalDebited: 0,
          pendingPayout: 0,
          currency: FINANCE_CONFIG.DEFAULT_CURRENCY,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        currentBalance = 0;  // For transaction record
      } else {
        currentBalance = walletDoc.data()!.balance || 0;
        
        // P0-9 FIX: Update existing wallet (separate from creation)
        transaction.update(walletRef, {
          balance: admin.firestore.FieldValue.increment(amount),
          totalCredited: admin.firestore.FieldValue.increment(amount),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Create transaction record
      const transactionRef = admin.firestore().collection('transactions').doc(`topup_${requestId}`);
      transaction.set(transactionRef, {
        id: transactionRef.id,
        walletId: driverId,
        type: 'credit',
        source: 'topup',
        amount: amount,
        currency: FINANCE_CONFIG.DEFAULT_CURRENCY,
        balanceBefore: currentBalance,
        balanceAfter: currentBalance + amount,
        note: `Manual top-up approved by admin`,
        metadata: {
          requestId,
          adminId,
          notes: notes || null,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update request status
      transaction.update(requestRef, {
        status: 'approved',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        adminId,
        notes: notes || null,
      });

      console.log('[ApproveTopup] Top-up approved successfully', {
        request_id: requestId,
        driver_id: driverId,
        amount,
        admin_id: adminId,
        balance_before: currentBalance,
        balance_after: currentBalance + amount,
      });

      // Log analytics event
      console.log('[Analytics] topup_approved', {
        request_id: requestId,
        driver_id: driverId,
        amount,
        admin_id: adminId,
      });

      return {
        success: true,
        message: 'Top-up request approved successfully',
      };
    });

    // If transaction returned early (already processed), return that result
    if (result && result.alreadyProcessed) {
      return result;
    }

    return {
      success: true,
      message: 'Top-up request approved successfully',
    };

  } catch (error: any) {
    console.error('[ApproveTopup] Error approving request:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to approve top-up request');
  }
});

/**
 * Callable function: Reject top-up request
 */
export const rejectTopupRequest = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check admin permissions
  if (!context.auth.token.isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const adminId = context.auth.uid;
  const { requestId, notes } = data;

  if (!requestId || typeof requestId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Request ID is required');
  }

  try {
    const requestRef = admin.firestore().collection('topup_requests').doc(requestId);
    const requestDoc = await requestRef.get();

    if (!requestDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Top-up request not found');
    }

    const requestData = requestDoc.data()!;

    if (requestData.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Request already processed');
    }

    await requestRef.update({
      status: 'rejected',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      adminId,
      notes: notes || 'Request rejected by admin',
    });

    console.log('[RejectTopup] Top-up rejected', {
      request_id: requestId,
      driver_id: requestData.driverId,
      amount: requestData.amount,
      admin_id: adminId,
      notes,
    });

    // Log analytics event
    console.log('[Analytics] topup_rejected', {
      request_id: requestId,
      driver_id: requestData.driverId,
      amount: requestData.amount,
      admin_id: adminId,
    });

    return {
      success: true,
      message: 'Top-up request rejected',
    };

  } catch (error: any) {
    console.error('[RejectTopup] Error rejecting request:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to reject top-up request');
  }
});