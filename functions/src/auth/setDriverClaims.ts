/**
 * Driver Claims Management
 * Sets custom claims for driver users
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Manually set driver claims (for existing drivers)
 */
export const manualSetDriverClaims = functions.https.onCall(async (data, context) => {
  const { uid } = data;

  if (!uid || typeof uid !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide a valid user ID'
    );
  }

  try {
    // Check if driver document exists
    const driverDoc = await admin.firestore().collection('drivers').doc(uid).get();
    
    if (!driverDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Driver document not found'
      );
    }

    const driverData = driverDoc.data()!;

    // Set custom claims
    await admin.auth().setCustomUserClaims(uid, {
      isDriver: true,
      role: 'driver',
      isVerified: driverData.isVerified || false,
      assignedAt: Date.now(),
    });

    console.log(`Manual driver claims set for user ${uid}`);
    
    return {
      success: true,
      message: `Driver claims set for user ${uid}`,
    };
  } catch (error) {
    console.error('Error setting driver claims:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to set driver claims'
    );
  }
});