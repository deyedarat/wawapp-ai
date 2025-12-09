/**
 * Admin Driver Management Actions
 * Block/unblock drivers and manage driver accounts
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Block a driver (admin action)
 */
export const adminBlockDriver = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to block drivers'
    );
  }

  // Require admin role
  const userClaims = context.auth.token;
  if (!userClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can block drivers'
    );
  }

  const { driverId, reason } = data;

  if (!driverId || typeof driverId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide a valid driver ID'
    );
  }

  try {
    const db = admin.firestore();
    const driverRef = db.collection('drivers').doc(driverId);
    const driverDoc = await driverRef.get();

    if (!driverDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Driver not found'
      );
    }

    // Update driver status
    await driverRef.update({
      isBlocked: true,
      blockedAt: admin.firestore.FieldValue.serverTimestamp(),
      blockedBy: context.auth.uid,
      blockReason: reason || 'Blocked by admin',
      isOnline: false, // Force offline when blocked
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log the action
    await db.collection('admin_actions').add({
      action: 'blockDriver',
      driverId,
      reason: reason || 'No reason provided',
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // TODO: Optionally revoke driver's auth tokens
    // await admin.auth().revokeRefreshTokens(driverId);

    return {
      success: true,
      message: `Driver ${driverId} has been blocked`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error blocking driver:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to block driver'
    );
  }
});

/**
 * Unblock a driver (admin action)
 */
export const adminUnblockDriver = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to unblock drivers'
    );
  }

  // Require admin role
  const userClaims = context.auth.token;
  if (!userClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can unblock drivers'
    );
  }

  const { driverId } = data;

  if (!driverId || typeof driverId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide a valid driver ID'
    );
  }

  try {
    const db = admin.firestore();
    const driverRef = db.collection('drivers').doc(driverId);
    const driverDoc = await driverRef.get();

    if (!driverDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Driver not found'
      );
    }

    // Update driver status
    await driverRef.update({
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
      action: 'unblockDriver',
      driverId,
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: `Driver ${driverId} has been unblocked`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error unblocking driver:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to unblock driver'
    );
  }
});

/**
 * Verify a driver (admin action)
 */
export const adminVerifyDriver = functions.https.onCall(async (data, context) => {
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
      'Only admins can verify drivers'
    );
  }

  const { driverId, isVerified } = data;

  if (!driverId || typeof isVerified !== 'boolean') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide driver ID and verification status'
    );
  }

  try {
    const db = admin.firestore();
    const driverRef = db.collection('drivers').doc(driverId);

    await driverRef.update({
      isVerified,
      verifiedAt: isVerified ? admin.firestore.FieldValue.serverTimestamp() : admin.firestore.FieldValue.delete(),
      verifiedBy: isVerified ? context.auth.uid : admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log the action
    await db.collection('admin_actions').add({
      action: isVerified ? 'verifyDriver' : 'unverifyDriver',
      driverId,
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: `Driver ${driverId} verification status updated`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error updating driver verification:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update driver verification'
    );
  }
});
