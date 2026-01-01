/**
 * PIN Rate Limiting and Brute-Force Protection
 *
 * Implements progressive lockout to prevent PIN brute-force attacks:
 * - 3 attempts = 1 minute lockout
 * - 6 attempts = 5 minute lockout
 * - 10 attempts = 1 hour lockout
 *
 * Uses Firestore for distributed state across Cloud Function instances.
 *
 * Security Fix: P0-AUTH-1 - PIN Brute Force Protection
 * P0-11 Enhancement: IP address captured in createCustomToken for additional protection
 */

import * as admin from 'firebase-admin';

interface RateLimitResult {
  allowed: boolean;
  remainingAttempts?: number;
  lockedUntilSeconds?: number;
  message?: string;
}

/**
 * Check if phone number is rate limited for PIN attempts
 *
 * @param phoneE164 - Phone number in E.164 format (e.g., "+22236123456")
 * @returns Rate limit check result
 */
export async function checkRateLimit(phoneE164: string): Promise<RateLimitResult> {
  const db = admin.firestore();
  const docId = phoneE164.replace(/[^0-9]/g, '');
  const rateLimitRef = db.collection('pin_rate_limits').doc(docId);

  try {
    const doc = await rateLimitRef.get();

    // First attempt - no rate limit record exists yet
    if (!doc.exists) {
      return { allowed: true, remainingAttempts: 10 };
    }

    const data = doc.data()!;
    const now = admin.firestore.Timestamp.now();

    // Check if currently locked
    if (data.lockedUntil && data.lockedUntil.toMillis() > now.toMillis()) {
      const remainingSeconds = Math.ceil((data.lockedUntil.toMillis() - now.toMillis()) / 1000);

      // Format Arabic message based on duration
      let message = `الحساب مقفل. حاول بعد ${remainingSeconds} ثانية`;
      if (remainingSeconds >= 60) {
        const minutes = Math.ceil(remainingSeconds / 60);
        message = `الحساب مقفل. حاول بعد ${minutes} دقيقة`;
      }
      if (remainingSeconds >= 3600) {
        message = `الحساب مقفل لمدة ساعة بسبب المحاولات الكثيرة`;
      }

      console.log(`[RateLimit] Account locked`, {
        phone: phoneE164,
        remainingSeconds,
        lockLevel: data.lockLevel
      });

      return {
        allowed: false,
        lockedUntilSeconds: remainingSeconds,
        message
      };
    }

    // Lock expired - delete record to reset
    if (data.lockedUntil && data.lockedUntil.toMillis() <= now.toMillis()) {
      console.log(`[RateLimit] Lock expired, resetting counter`, { phone: phoneE164 });
      await rateLimitRef.delete();
      return { allowed: true, remainingAttempts: 10 };
    }

    // Not locked - check attempt count
    const attemptCount = data.attemptCount || 0;
    const remainingAttempts = Math.max(0, 10 - attemptCount);

    console.log(`[RateLimit] Check passed`, {
      phone: phoneE164,
      attemptCount,
      remainingAttempts
    });

    return { allowed: true, remainingAttempts };

  } catch (error) {
    // Bug #7 FIX: SECURITY - Fail-closed for authentication
    // If we cannot verify rate limit, we must deny to prevent brute force attacks
    console.error('[RateLimit] CRITICAL: Error checking rate limit, DENYING request for security', {
      phone: phoneE164,
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
      timestamp: new Date().toISOString(),
    });

    // Alert operations team (integrate with monitoring system)
    // TODO: Send to Sentry/CloudWatch/monitoring system

    return {
      allowed: false,
      message: 'خطأ في النظام. حاول مرة أخرى بعد قليل', // System error. Try again later.
      lockedUntilSeconds: 60, // Temporary 1-minute backoff
    };
  }
}

/**
 * Record a failed PIN attempt with progressive lockout
 *
 * Uses Firestore transaction to prevent race conditions when multiple
 * requests arrive simultaneously.
 *
 * @param phoneE164 - Phone number in E.164 format
 */
export async function recordFailedAttempt(phoneE164: string): Promise<void> {
  const db = admin.firestore();
  const docId = phoneE164.replace(/[^0-9]/g, '');
  const rateLimitRef = db.collection('pin_rate_limits').doc(docId);

  try {
    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);
      const now = admin.firestore.Timestamp.now();

      let attemptCount = 1;

      if (doc.exists) {
        const data = doc.data()!;
        attemptCount = (data.attemptCount || 0) + 1;
      }

      // Calculate progressive lockout
      let lockedUntil: admin.firestore.Timestamp | null = null;
      let lockLevel = 0;

      if (attemptCount >= 10) {
        // 10+ attempts = 1 hour lockout
        lockedUntil = new admin.firestore.Timestamp(now.seconds + 3600, 0);
        lockLevel = 3;
      } else if (attemptCount >= 6) {
        // 6-9 attempts = 5 minute lockout
        lockedUntil = new admin.firestore.Timestamp(now.seconds + 300, 0);
        lockLevel = 2;
      } else if (attemptCount >= 3) {
        // 3-5 attempts = 1 minute lockout
        lockedUntil = new admin.firestore.Timestamp(now.seconds + 60, 0);
        lockLevel = 1;
      }

      const record: any = {
        phoneE164,
        attemptCount,
        lockedUntil,
        lockLevel,
        lastAttemptAt: now,
        updatedAt: now,
      };

      if (!doc.exists) {
        record.id = docId;
        record.createdAt = now;
      }

      transaction.set(rateLimitRef, record, { merge: true });

      console.log(`[RateLimit] Recorded failed attempt ${attemptCount}/10`, {
        phone: phoneE164,
        lockLevel,
        lockedUntil: lockedUntil?.toDate(),
        lockDuration: lockLevel === 0 ? 'none' : lockLevel === 1 ? '1min' : lockLevel === 2 ? '5min' : '1hour'
      });
    });
  } catch (error) {
    // Don't throw - we don't want rate limiting failures to block auth
    console.error('[RateLimit] Error recording failed attempt', {
      phone: phoneE164,
      error: error instanceof Error ? error.message : String(error)
    });
  }
}

/**
 * Reset rate limit counter after successful authentication
 *
 * Called when user successfully logs in with correct PIN.
 * Deletes the rate limit document to give user fresh 10 attempts.
 *
 * @param phoneE164 - Phone number in E.164 format
 */
export async function resetRateLimit(phoneE164: string): Promise<void> {
  const db = admin.firestore();
  const docId = phoneE164.replace(/[^0-9]/g, '');
  const rateLimitRef = db.collection('pin_rate_limits').doc(docId);

  try {
    await rateLimitRef.delete();
    console.log(`[RateLimit] Reset counter after successful login`, { phone: phoneE164 });
  } catch (error) {
    // Don't throw - we don't want this to block successful auth
    console.error('[RateLimit] Error resetting rate limit', {
      phone: phoneE164,
      error: error instanceof Error ? error.message : String(error)
    });
  }
}
