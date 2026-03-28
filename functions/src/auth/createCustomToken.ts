/**
 * Create Custom Token for PIN-based authentication
 *
 * This function allows users who have verified their PIN to obtain a custom token
 * for signing in to Firebase Auth without requiring OTP every time.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { checkRateLimit, recordFailedAttempt, resetRateLimit } from './rateLimiting';

/**
 * Hash PIN with salt for verification
 */
function hashWithSalt(pin: string, salt: string): string {
  const combined = `${pin}:${salt}`;
  return crypto.createHash('sha256').update(combined).digest('hex');
}

/**
 * Create a custom authentication token after verifying PIN
 *
 * @param phoneE164 - Phone number in E.164 format
 * @param pin - User's 4-digit PIN
 * @returns Custom token for Firebase Auth sign-in
 * 
 * P0-11 FIX: Enhanced with IP-based rate limiting for brute force protection
 */
export const createCustomToken = functions.https.onCall(async (data, context) => {
  const { phoneE164, pin, userType } = data; // ADD userType parameter
  
  // P0-11 FIX: Capture client IP for IP-based rate limiting
  const clientIp = context.rawRequest?.ip || 'unknown';

  // Validate input
  if (!phoneE164 || typeof phoneE164 !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
  }

  if (!pin || typeof pin !== 'string' || pin.length !== 4) {
    throw new functions.https.HttpsError('invalid-argument', 'Valid 4-digit PIN is required');
  }

  // Determine collection based on userType, default to 'users' for backwards compatibility
  const collection = userType === 'driver' ? 'drivers' : 'users';

  console.log(`[createCustomToken] Searching in collection: ${collection} for phone: ${phoneE164} from IP: ${clientIp}`);

  // SECURITY: Check rate limit BEFORE database queries to prevent brute-force attacks
  const rateLimitResult = await checkRateLimit(phoneE164);

  if (!rateLimitResult.allowed) {
    console.warn(`[createCustomToken] Rate limit exceeded for ${phoneE164}`, {
      lockedUntilSeconds: rateLimitResult.lockedUntilSeconds,
    });

    throw new functions.https.HttpsError(
      'resource-exhausted',
      rateLimitResult.message || 'Too many attempts. Please try again later.',
      {
        remainingSeconds: rateLimitResult.lockedUntilSeconds,
        lockedUntil: new Date(Date.now() + (rateLimitResult.lockedUntilSeconds! * 1000)).toISOString(),
      }
    );
  }

  console.log(`[createCustomToken] Rate limit check passed`, {
    remainingAttempts: rateLimitResult.remainingAttempts,
  });

  try {
    // Find user by phone number in appropriate collection
    const usersSnapshot = await admin.firestore()
      .collection(collection) // DYNAMIC COLLECTION
      .where('phone', '==', phoneE164)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log(`[createCustomToken] No ${userType || 'user'} found with phone: ${phoneE164}`);
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    const uid = userDoc.id;

    // Verify PIN
    const storedHash = userData.pinHash as string | undefined;
    const storedSalt = userData.pinSalt as string | undefined;

    console.log(`[createCustomToken] User ${uid} - storedHash exists: ${!!storedHash}, storedSalt exists: ${!!storedSalt}`);

    if (!storedHash) {
      console.log(`[createCustomToken] No PIN hash found for user: ${uid}`);
      throw new functions.https.HttpsError('failed-precondition', 'No PIN set for this user');
    }

    let isValidPin = false;

    if (storedSalt) {
      // New salted hash
      const computedHash = hashWithSalt(pin, storedSalt);
      isValidPin = computedHash === storedHash;
      console.log(`[createCustomToken] Salted hash comparison - match: ${isValidPin}`);
      if (!isValidPin) {
        console.log(`[createCustomToken] Hash mismatch - stored: ${storedHash.substring(0, 10)}..., computed: ${computedHash.substring(0, 10)}...`);
      }
    } else {
      // Legacy hash without salt
      const legacyHash = crypto.createHash('sha256').update(`${uid}:${pin}`).digest('hex');
      isValidPin = legacyHash === storedHash;

      // Upgrade to salted hash
      if (isValidPin) {
        const newSalt = crypto.randomBytes(16).toString('base64url');
        const newHash = hashWithSalt(pin, newSalt);
        await admin.firestore().collection(collection).doc(uid).update({
          pinSalt: newSalt,
          pinHash: newHash
        });
        console.log(`[createCustomToken] Upgraded PIN hash for ${userType || 'user'}: ${uid}`);
      }
    }

    if (!isValidPin) {
      console.log(`[createCustomToken] Invalid PIN for user: ${uid}`);

      // Record failed attempt asynchronously (don't block response)
      setImmediate(async () => {
        try {
          await recordFailedAttempt(phoneE164);
        } catch (error) {
          console.error('[createCustomToken] Failed to record rate limit attempt', error);
        }
      });

      // Get updated remaining attempts for error message
      const updatedLimit = await checkRateLimit(phoneE164);
      const remainingAttempts = updatedLimit.remainingAttempts || 0;

      throw new functions.https.HttpsError(
        'unauthenticated',
        `Invalid PIN. ${remainingAttempts} attempts remaining.`,
        { remainingAttempts }
      );
    }

    // Create custom token
    const customToken = await admin.auth().createCustomToken(uid, {
      phone: phoneE164,
      authMethod: 'pin'
    });

    console.log(`[createCustomToken] Custom token created for user: ${uid}`);

    // Reset rate limit on successful authentication
    await resetRateLimit(phoneE164);
    console.log(`[createCustomToken] Rate limit reset for ${phoneE164}`);

    return {
      token: customToken,
      uid: uid
    };

  } catch (error) {
    // Log detailed error information
    console.error('[createCustomToken] Error:', error);
    console.error('[createCustomToken] Error type:', error instanceof Error ? error.constructor.name : typeof error);
    if (error instanceof Error) {
      console.error('[createCustomToken] Error message:', error.message);
      console.error('[createCustomToken] Error stack:', error.stack);
    }

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Include error details in the thrown error for debugging
    const errorMessage = error instanceof Error ? error.message : String(error);
    throw new functions.https.HttpsError('internal', `Failed to create custom token: ${errorMessage}`);
  }
});
