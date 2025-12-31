/**
 * Cloud Function: Create Driver Top-up Request
 * 
 * Phase D: Allows drivers to create manual top-up requests that require admin approval.
 * 
 * Rules:
 * - Auth required, must be driver
 * - Validate amount (positive, reasonable max)
 * - Create pending topup request
 * 
 * Author: WawApp Development Team (Phase D Implementation)
 * Last Updated: 2025-12-28
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Configuration
const MAX_TOPUP_AMOUNT = 100000; // 100,000 MRU maximum
const MIN_TOPUP_AMOUNT = 1000; // 1,000 MRU minimum

/**
 * Callable function: Create top-up request
 */
export const createTopupRequest = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const driverId = context.auth.uid;
  const { amount } = data;

  // Validate amount
  if (!amount || typeof amount !== 'number') {
    throw new functions.https.HttpsError('invalid-argument', 'Amount must be a number');
  }

  if (amount < MIN_TOPUP_AMOUNT || amount > MAX_TOPUP_AMOUNT) {
    throw new functions.https.HttpsError(
      'invalid-argument', 
      `Amount must be between ${MIN_TOPUP_AMOUNT} and ${MAX_TOPUP_AMOUNT} MRU`
    );
  }

  // Verify user is a driver
  try {
    const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
    if (!driverDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Driver profile not found');
    }
  } catch (error) {
    console.error('[CreateTopup] Error verifying driver:', error);
    throw new functions.https.HttpsError('internal', 'Failed to verify driver status');
  }

  try {
    // Create top-up request
    const requestRef = admin.firestore().collection('topup_requests').doc();
    await requestRef.set({
      id: requestRef.id,
      driverId,
      amount,
      status: 'pending',
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: null,
      adminId: null,
      notes: null,
    });

    console.log('[CreateTopup] Top-up request created', {
      request_id: requestRef.id,
      driver_id: driverId,
      amount,
    });

    // Log analytics event
    console.log('[Analytics] topup_request_created', {
      request_id: requestRef.id,
      driver_id: driverId,
      amount,
    });

    return {
      success: true,
      requestId: requestRef.id,
      message: 'Top-up request created successfully',
    };

  } catch (error) {
    console.error('[CreateTopup] Error creating request:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create top-up request');
  }
});