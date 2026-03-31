import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { resetRateLimit } from './rateLimiting';

const MAURITANIA_PHONE_REGEX = /^\+222[2-4]\d{7}$/;
const OTP_CODE_REGEX = /^\d{6}$/;

export const verifyOtp = functions
  .runWith({ secrets: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_VERIFY_SERVICE_SID'] })
  .https.onCall(async (data, _context) => {
    const { phone, code, userType } = data;

    // Validate input
    if (!phone || typeof phone !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
    }

    if (!MAURITANIA_PHONE_REGEX.test(phone)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid Mauritanian phone number');
    }

    if (!code || typeof code !== 'string' || !OTP_CODE_REGEX.test(code)) {
      throw new functions.https.HttpsError('invalid-argument', 'Valid 6-digit code is required');
    }

    // Verify OTP with Twilio
    try {
      const twilioClient = require('twilio')(
        process.env.TWILIO_ACCOUNT_SID,
        process.env.TWILIO_AUTH_TOKEN
      );

      const result = await twilioClient.verify.v2
        .services(process.env.TWILIO_VERIFY_SERVICE_SID!)
        .verificationChecks.create({ to: phone, code: code });

      if (result.status !== 'approved') {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid or expired OTP code');
      }
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      console.error('[verifyOtp] Twilio error:', error instanceof Error ? error.message : String(error));
      throw new functions.https.HttpsError('internal', 'Authentication failed');
    }

    // OTP approved — find or create user
    try {
      const collection = userType === 'driver' ? 'drivers' : 'users';

      const snapshot = await admin.firestore()
        .collection(collection)
        .where('phone', '==', phone)
        .limit(1)
        .get();

      let uid: string;
      let isNewUser = false;

      if (!snapshot.empty) {
        uid = snapshot.docs[0].id;
        console.log(`[verifyOtp] Existing user found: ${uid}`);
      } else {
        const newUser = await admin.auth().createUser({ phoneNumber: phone });
        uid = newUser.uid;
        isNewUser = true;

        await admin.firestore().collection(collection).doc(uid).set({
          phone,
          createdAt: admin.firestore.Timestamp.now(),
          authMethod: 'otp',
        });

        console.log(`[verifyOtp] New user created: ${uid}`);
      }

      const customToken = await admin.auth().createCustomToken(uid, {
        phone,
        authMethod: 'otp',
      });

      await resetRateLimit(phone);

      return { customToken, isNewUser, uid };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      console.error('[verifyOtp] Error:', error instanceof Error ? error.message : String(error));
      throw new functions.https.HttpsError('internal', 'Authentication failed');
    }
  });
