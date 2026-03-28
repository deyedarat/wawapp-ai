/**
 * Admin Client Management Actions
 * Verify/unverify clients and manage client accounts
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Set client verification status (admin action)
 */
export const adminSetClientVerification = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to verify clients'
    );
  }

  // Require admin role
  const userClaims = context.auth.token;
  if (!userClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can verify clients'
    );
  }

  const { clientId, isVerified } = data;

  if (!clientId || typeof isVerified !== 'boolean') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide client ID and verification status'
    );
  }

  try {
    const db = admin.firestore();
    const clientRef = db.collection('clients').doc(clientId);
    const clientDoc = await clientRef.get();

    if (!clientDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Client not found'
      );
    }

    // Update client verification status
    await clientRef.update({
      isVerified,
      verifiedAt: isVerified ? admin.firestore.FieldValue.serverTimestamp() : admin.firestore.FieldValue.delete(),
      verifiedBy: isVerified ? context.auth.uid : admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log the action
    await db.collection('admin_actions').add({
      action: isVerified ? 'verifyClient' : 'unverifyClient',
      clientId,
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: `Client ${clientId} verification status updated to ${isVerified}`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error updating client verification:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update client verification'
    );
  }
});

/**
 * Block a client (admin action)
 */
export const adminBlockClient = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated'
    );
  }

  // Require admin role
  const userClaims = context.auth.token;
  if (!userClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can block clients'
    );
  }

  const { clientId, reason } = data;

  if (!clientId || typeof clientId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide a valid client ID'
    );
  }

  try {
    const db = admin.firestore();
    const clientRef = db.collection('clients').doc(clientId);
    const clientDoc = await clientRef.get();

    if (!clientDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Client not found'
      );
    }

    // Update client status
    await clientRef.update({
      isBlocked: true,
      blockedAt: admin.firestore.FieldValue.serverTimestamp(),
      blockedBy: context.auth.uid,
      blockReason: reason || 'Blocked by admin',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log the action
    await db.collection('admin_actions').add({
      action: 'blockClient',
      clientId,
      reason: reason || 'No reason provided',
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: `Client ${clientId} has been blocked`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error blocking client:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to block client'
    );
  }
});

/**
 * Unblock a client (admin action)
 */
export const adminUnblockClient = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated'
    );
  }

  // Require admin role
  const userClaims = context.auth.token;
  if (!userClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can unblock clients'
    );
  }

  const { clientId } = data;

  if (!clientId || typeof clientId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide a valid client ID'
    );
  }

  try {
    const db = admin.firestore();
    const clientRef = db.collection('clients').doc(clientId);
    const clientDoc = await clientRef.get();

    if (!clientDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Client not found'
      );
    }

    // Update client status
    await clientRef.update({
      isBlocked: false,
      unblockedAt: admin.firestore.FieldValue.serverTimestamp(),
      unblockedBy: context.auth.uid,
      blockReason: admin.firestore.FieldValue.delete(),
      blockedAt: admin.firestore.FieldValue.delete(),
      blockedBy: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log the action
    await db.collection('admin_actions').add({
      action: 'unblockClient',
      clientId,
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: `Client ${clientId} has been unblocked`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error unblocking client:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to unblock client'
    );
  }
});
