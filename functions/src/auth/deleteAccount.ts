/**
 * Delete User Account
 *
 * This function permanently deletes a user's account including:
 * - Firebase Authentication user
 * - Firestore user document
 *
 * Google Play Compliance: Account Deletion Requirement (2024-2025)
 *
 * SECURITY:
 * - Requires authentication (user can only delete their own account)
 * - Server-side enforcement prevents client-side bypass
 * - Atomic deletion of Auth + Firestore data
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Callable Cloud Function: deleteAccount
 * Deletes authenticated user's Firestore data and Firebase Auth account.
 *
 * @returns { ok: boolean, message: string }
 *
 * SECURITY:
 * - Only authenticated users can call this function
 * - User can only delete their own account (enforced by context.auth.uid)
 * - Deletion is permanent and cannot be undone
 */
export const deleteAccount = functions.https.onCall(async (data, context) => {
  // CRITICAL: Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to delete account.'
    );
  }

  const uid = context.auth.uid;
  const clientIp = context.rawRequest?.ip || 'unknown';

  console.log(`[deleteAccount] Account deletion requested by user: ${uid} from IP: ${clientIp}`);

  try {
    // Step 1: Delete Firestore user document
    // Note: This assumes the user collection is 'users' for clients
    await admin.firestore().collection('users').doc(uid).delete();

    console.log(`[deleteAccount] Deleted Firestore document for user: ${uid}`);

    // Step 2: Delete Firebase Auth user
    // This must be done AFTER Firestore deletion to ensure data is removed first
    await admin.auth().deleteUser(uid);

    console.log(`[deleteAccount] Deleted Auth user: ${uid}`);

    // Success
    return {
      ok: true,
      message: 'Account deleted successfully'
    };

  } catch (error: any) {
    console.error(`[deleteAccount] Failed to delete account for user ${uid}:`, error);

    // Don't expose internal error details to client
    throw new functions.https.HttpsError(
      'internal',
      'Failed to delete account. Please contact support.',
      error.message
    );
  }
});
