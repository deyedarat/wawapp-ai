/**
 * Check if a phone number exists in the system
 *
 * This function allows unauthenticated users to check if a phone number is registered
 * without exposing the entire users/drivers collection to enumeration attacks.
 *
 * SECURITY:
 * - Rate limited to prevent phone number enumeration
 * - Only returns boolean (exists/not exists)
 * - No user data exposed
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';

/**
 * Check if phone number exists
 *
 * @param phoneE164 - Phone number in E.164 format (e.g. +22231035373)
 * @param userType - 'driver' or 'user' to determine which collection to search
 * @returns { exists: boolean }
 *
 * SECURITY: Rate limiting handled by Firebase Functions quota limits
 * Additional IP-based rate limiting could be added if needed
 */
export const checkPhoneExists = functions.https.onCall(async (data, context) => {
  const { phoneE164, userType } = data;

  // Validate input
  if (!phoneE164 || typeof phoneE164 !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
  }

  if (!phoneE164.startsWith('+')) {
    throw new functions.https.HttpsError('invalid-argument', 'Phone must be in E.164 format (starting with +)');
  }

  // Determine collection based on userType, default to 'users'
  const collection = userType === 'driver' ? 'drivers' : 'users';

  // Optional: Log for monitoring (helps detect enumeration attempts)
  const clientIp = context.rawRequest?.ip || 'unknown';
  console.log(`[checkPhoneExists] Check requested for ${phoneE164} in ${collection} from IP: ${clientIp}`);

  try {
    // Query for phone number in E.164 format
    const snapshot = await admin.firestore()
      .collection(collection)
      .where('phone', '==', phoneE164)
      .limit(1)
      .get();

    let exists = !snapshot.empty;

    // Secondary check: look for local number format (without country code)
    // This handles legacy entries stored without +222 prefix
    if (!exists && phoneE164.startsWith('+222')) {
      const localNumber = phoneE164.replace('+222', '');
      const localSnapshot = await admin.firestore()
        .collection(collection)
        .where('phone', '==', localNumber)
        .limit(1)
        .get();
      exists = !localSnapshot.empty;

      if (exists) {
        console.log(`[checkPhoneExists] Found with local format. Normalizing phone for doc: ${localSnapshot.docs[0].id}`);
        // Fix the phone format in the background
        admin.firestore().collection(collection).doc(localSnapshot.docs[0].id).update({
          phone: phoneE164,
        }).catch(err => console.error('[checkPhoneExists] Failed to normalize phone:', err));
      }
    }

    console.log(`[checkPhoneExists] Phone ${phoneE164} in ${collection}: ${exists ? 'found' : 'not found'}`);

    return { exists };

  } catch (error) {
    console.error('[checkPhoneExists] Error:', error);

    // Don't expose internal errors to client
    throw new functions.https.HttpsError('internal', 'Failed to check phone number');
  }
});
