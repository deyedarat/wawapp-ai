import * as functions from 'firebase-functions/v1';
import { checkRateLimit, checkOtpRateLimit, recordFailedAttempt } from './rateLimiting';

const MAURITANIA_PHONE_REGEX = /^\+222[2-4]\d{7}$/;

export const sendOtp = functions
  .runWith({ secrets: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_VERIFY_SERVICE_SID'] })
  .https.onCall(async (data, _context) => {
    const { phone } = data;

    // Validate input
    if (!phone || typeof phone !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
    }

    if (!MAURITANIA_PHONE_REGEX.test(phone)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid Mauritanian phone number');
    }

    // OTP-specific rate limit: max 2 SMS per 10 minutes
    const otpLimit = await checkOtpRateLimit(phone);
    if (!otpLimit.allowed) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        otpLimit.message || 'Too many OTP requests. Please wait.',
        { remainingSeconds: otpLimit.lockedUntilSeconds }
      );
    }

    // PIN brute-force rate limit check
    const rateLimitResult = await checkRateLimit(phone);
    if (!rateLimitResult.allowed) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        rateLimitResult.message || 'Too many attempts. Please try again later.',
        { remainingSeconds: rateLimitResult.lockedUntilSeconds }
      );
    }

    try {
      const twilioClient = require('twilio')(
        process.env.TWILIO_ACCOUNT_SID,
        process.env.TWILIO_AUTH_TOKEN
      );

      await twilioClient.verify.v2
        .services(process.env.TWILIO_VERIFY_SERVICE_SID!)
        .verifications.create({ to: phone, channel: 'sms' });

      console.log('[sendOtp] OTP sent successfully');
      return { success: true };
    } catch (error) {
      console.error('[sendOtp] Twilio error:', error instanceof Error ? error.message : String(error));
      await recordFailedAttempt(phone);
      throw new functions.https.HttpsError('internal', 'Failed to send OTP');
    }
  });
