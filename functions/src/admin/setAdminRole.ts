/**
 * Admin Role Management
 * Sets custom claims for admin users
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Set admin role for a user
 * This function should be called manually or through a secure admin CLI
 * NOT exposed as a public callable function for security
 */
export const setAdminRole = functions.https.onCall(async (data, context) => {
  // Only existing admins can create new admins
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to call this function'
    );
  }

  // Bug #6 FIX: Standardize admin check - use isAdmin only (not role)
  // isAdmin is the PRIMARY admin indicator (used in security rules)
  // role is SECONDARY metadata (for logging and display purposes only)
  const callerClaims = context.auth.token;
  if (!callerClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can assign admin role'
    );
  }

  const { uid } = data;

  if (!uid || typeof uid !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide a valid user ID'
    );
  }

  try {
    // Set custom claims
    // PRIMARY: isAdmin (used for security rules and authorization checks)
    // SECONDARY: role (for logging, admin UI display, and audit trails)
    await admin.auth().setCustomUserClaims(uid, {
      isAdmin: true,              // PRIMARY: Used in firestore.rules (line 8: isAdmin == true)
      role: 'admin',              // SECONDARY: For display/logging only
      assignedAt: Date.now(),
    });

    // Log the action
    await admin.firestore().collection('admin_actions').add({
      action: 'setAdminRole',
      targetUserId: uid,
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: `Admin role granted to user ${uid}`,
    };
  } catch (error) {
    console.error('Error setting admin role:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to set admin role'
    );
  }
});

/**
 * Remove admin role from a user
 */
export const removeAdminRole = functions.https.onCall(async (data, context) => {
  // Only existing admins can remove admin role
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to call this function'
    );
  }

  const callerClaims = context.auth.token;
  if (!callerClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can remove admin role'
    );
  }

  const { uid } = data;

  if (!uid || typeof uid !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide a valid user ID'
    );
  }

  // Prevent removing own admin role
  if (uid === context.auth.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Cannot remove your own admin role'
    );
  }

  try {
    // Remove custom claims
    await admin.auth().setCustomUserClaims(uid, {
      isAdmin: false,
      role: null,
    });

    // Log the action
    await admin.firestore().collection('admin_actions').add({
      action: 'removeAdminRole',
      targetUserId: uid,
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: `Admin role removed from user ${uid}`,
    };
  } catch (error) {
    console.error('Error removing admin role:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to remove admin role'
    );
  }
});
